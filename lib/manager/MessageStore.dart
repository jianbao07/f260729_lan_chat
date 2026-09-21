import 'dart:io';
import 'dart:math';

import 'package:path_provider/path_provider.dart';
import 'package:yf_code/bean/MessageBaseBean.dart';
import 'package:yf_code/bean/ConversationIndex.dart';
import 'package:yf_code/bean/MessageSendFileBean.dart';
import 'package:yf_code/bean/MessageTextBean.dart';
import 'package:yf_code/enum/FileTransferState.dart';
import 'package:yf_code/enum/MessageType.dart';
import 'package:yf_code/model/ConversationModel.dart';
import 'package:yf_code/model/MessageModel.dart';
import 'package:yf_code/utils/FileUtils.dart';
import 'package:yf_code/utils/log.dart';

class MessageStore {
  MessageStore._();
  static const _PAGE_SIZE=20;
  static final Map<String, ConversationIndex> conversationIndexMap = {};//会话id->会话index.json
  static final Map<String, List<Message>> historyMessages = {};//会话id->消息
  static final Map<String, MessageModel> conversationMessageModels = {};
  static final Map<String, Future<void>> _writeQueues = {};
  static final Random _random = Random.secure();
  static late String messageRecordDir;


  static Future<void> init() async {
    final support = await getApplicationSupportDirectory();
    final dir = Directory(
      '${support.path}${Platform.pathSeparator}message',
    );
    await dir.create(recursive: true);
    messageRecordDir=dir.path;
    await initMessage();
  }

  static Future<void> initMessage() async {
    final root = Directory(messageRecordDir);
    if (!await root.exists()) return;

    await for (final entity in root.list()) {
      if (entity is! Directory) continue;
      try {
        await _loadConversationDir(entity);
      } catch (e) {
        iLog('加载会话失败 path=${entity.path} err=$e');
      }
    }
    _syncConversations();
  }

  static String newMessageId(MessageType type) {
    return '${type.code}-${_generateUuid()}';
  }

  static void addMessage(Message message) {
    if (_isExists(message)) return;
    final conversationId = message.base?.conversationId;
    if (conversationId == null) {
      return;
    }
    historyMessages.putIfAbsent(conversationId, () => []).add(message);
    _getConversationModel(message)?.addMessage(message);
    ConversationModel.instance.onConversation(message);
    _enqueueWrite(conversationId, () => _persistNewMessage(message, conversationId));
  }

  static Future<void> _persistNewMessage(Message message, String conversationId) async {
    final index = await _getConversationIndex(conversationId);
    final pages = index.pages ??= [];
    final Pages page;
    if (pages.isEmpty || (pages.last.count ?? 0) >= _PAGE_SIZE) {
      page = Pages(name: '${pages.length + 1}.json', count: 0);
      pages.add(page);
    } else {
      page = pages.last;
    }
    await _addMessageToPage(message, index, page);
  }

  static Future<void> _addMessageToPage(Message message, ConversationIndex index, Pages page) async {
    final currentDir = index.currentDir;
    final pageName = page.name;
    final conversationId = index.conversationId ?? message.base?.conversationId;
    if (currentDir == null || pageName == null || conversationId == null) return;
    message.pageName = pageName;

    final pageFile = File('$currentDir${Platform.pathSeparator}$pageName');
    final decoded = await FileUtils.readJson(pageFile);
    final List<dynamic> records;
    if (decoded is List) {
      records = decoded;
      records.add(message.toJson());
    } else if (await pageFile.exists()) {
      iLog('分页JSON损坏，从内存重建 path=${pageFile.path}');
      records = _pageRecordsFromMemory(conversationId, pageName);
    } else {
      records = [message.toJson()];
    }
    await FileUtils.writeJsonAtomic(pageFile, records);

    page.count = records.length;
    index.totalPages = index.pages?.length ?? 0;
    index.totalMessages = (index.pages ?? []).fold<int>(0, (sum, p) => sum + (p.count ?? 0));
    await FileUtils.writeJsonAtomic(File('$currentDir${Platform.pathSeparator}index.json'), index.toJson());
  }

  static Future<List<Message>> getMessage(String conversationId) async {
    final cached = historyMessages[conversationId];
    if (cached != null && cached.isNotEmpty) return cached;
    await loadMoreMessage(conversationId);
    return historyMessages[conversationId] ?? [];
  }

  static Future<List<Message>> loadMoreMessage(String conversationId) async {
    final index = await _getConversationIndex(conversationId);
    final currentDir = index.currentDir;
    final pages = index.pages ?? [];
    if (currentDir == null || pages.isEmpty) return [];

    final messages = historyMessages.putIfAbsent(conversationId, () => []);
    final int loadIndex;
    if (messages.isEmpty) {
      loadIndex = pages.length - 1;
    } else {
      final pageName = messages.first.pageName;
      if (pageName == null) return [];
      final pageIndex = pages.indexWhere((p) => p.name == pageName);
      if (pageIndex <= 0) return [];
      loadIndex = pageIndex - 1;
    }

    final pageName = pages[loadIndex].name;
    if (pageName == null) return [];
    final pageFile = File('$currentDir${Platform.pathSeparator}$pageName');
    final records = await FileUtils.readJson(pageFile);
    if (records is! List) {
      if (await pageFile.exists()) {
        iLog('分页JSON损坏，跳过加载 path=${pageFile.path}');
      }
      return [];
    }
    final loaded = <Message>[];
    var interrupted = false;
    for (final record in records) {
      final message = Message.fromJson(record);
      if (message == null) continue;
      message.pageName ??= pageName;
      if (messages.any((m) => m.messageId == message.messageId)) continue;
      if (_failInterruptedFileTransfer(message)) interrupted = true;
      loaded.add(message);
    }
    messages.insertAll(0, loaded);
    if (interrupted) {
      await FileUtils.writeJsonAtomic(pageFile, _pageRecordsFromMemory(conversationId, pageName));
    }
    return loaded;
  }

  static void onChangeMessage(Message message) {
    final conversationId = message.base?.conversationId;
    if (conversationId == null) return;

    final messages = historyMessages[conversationId];
    if (messages != null) {
      final i = messages.indexWhere((m) => m.messageId == message.messageId);
      if (i >= 0) messages[i] = message;
    }
    conversationMessageModels[conversationId]?.onChangeMessage(message);
    _enqueueWrite(conversationId, () => _persistChangedMessage(message, conversationId));
  }

  static Future<void> _persistChangedMessage(Message message, String conversationId) async {
    final pageName = message.pageName;
    if (pageName == null) return;

    final index = await _getConversationIndex(conversationId);
    final currentDir = index.currentDir;
    if (currentDir == null) return;

    final pageFile = File('$currentDir${Platform.pathSeparator}$pageName');
    final decoded = await FileUtils.readJson(pageFile);
    if (decoded is List) {
      final recordIndex = decoded.indexWhere((item) {
        return item is Map && item['message_id']?.toString() == message.messageId;
      });
      if (recordIndex < 0) return;
      decoded[recordIndex] = message.toJson();
      await FileUtils.writeJsonAtomic(pageFile, decoded);
      return;
    }
    if (!await pageFile.exists()) return;
    iLog('分页JSON损坏，从内存重建 path=${pageFile.path}');
    await FileUtils.writeJsonAtomic(pageFile, _pageRecordsFromMemory(conversationId, pageName));
  }

  static Future<ConversationIndex> _getConversationIndex(String conversationId) async {
    final cached = conversationIndexMap[conversationId];
    if (cached != null) return cached;

    final dir = Directory('$messageRecordDir${Platform.pathSeparator}$conversationId');
    if (!(await dir.exists())) {
      await dir.create(recursive: true);
    }
    final indexFile = File('${dir.path}${Platform.pathSeparator}index.json');
    late final ConversationIndex index;
    if (!await indexFile.exists()) {
      index = ConversationIndex(
        conversationId: conversationId,
        currentDir: dir.path,
        totalMessages: 0,
        totalPages: 0,
        pages: [],
      );
      await FileUtils.writeJsonAtomic(indexFile, index.toJson());
    } else {
      final json = await FileUtils.readJson(indexFile);
      if (json != null) {
        index = ConversationIndex.fromJson(json);
        index.currentDir = dir.path;
      } else {
        iLog('会话索引损坏，尝试从分页文件恢复 conversationId=$conversationId');
        index = await _recoverIndex(conversationId, dir);
        await FileUtils.writeJsonAtomic(indexFile, index.toJson());
      }
    }
    conversationIndexMap[conversationId] = index;
    return index;
  }

  static MessageModel createMessageModel(String conversationId) {
    final existing = conversationMessageModels[conversationId];
    if (existing != null) return existing;

    final messages = historyMessages[conversationId] ?? [];
    final model = MessageModel(conversationId, messages);
    conversationMessageModels[conversationId] = model;
    if(messages.isEmpty){
      loadMoreMessage(conversationId);
    }
    return model;
  }

  static void destroyMessageModel(String conversationId) {
    conversationMessageModels.remove(conversationId)?.dispose();
  }

  static MessageModel? _getConversationModel(Message message) {
    final conversationId = message.base?.conversationId;
    if (conversationId == null) return null;
    return conversationMessageModels[conversationId];
  }

  static void _syncConversations() {
    for (final messages in historyMessages.values) {
      if (messages.isEmpty) continue;
      Message? last;
      for (var i = messages.length - 1; i >= 0; i--) {
        final m = messages[i];
        if (m is MessageTextBean || m is MessageSendFileBean) {
          last = m;
          break;
        }
      }
      last ??= messages.last;
      ConversationModel.instance.onConversation(last);
    }
  }

  static Future<void> _loadConversationDir(Directory dir) async {
    final conversationId = dir.path.split(Platform.pathSeparator).last;
    if (conversationId.isEmpty) return;

    final indexFile = File('${dir.path}${Platform.pathSeparator}index.json');
    ConversationIndex index;
    final json = await FileUtils.readJson(indexFile);
    if (json != null) {
      index = ConversationIndex.fromJson(json);
    } else if (await indexFile.exists()) {
      iLog('会话索引损坏，尝试从分页文件恢复 conversationId=$conversationId');
      index = await _recoverIndex(conversationId, dir);
      await FileUtils.writeJsonAtomic(indexFile, index.toJson());
    } else {
      return;
    }
    index.currentDir = dir.path;
    conversationIndexMap[conversationId] = index;

    final pages = index.pages ?? [];
    if (pages.isEmpty) return;
    final pageName = pages.last.name;
    if (pageName == null) return;

    final pageFile = File('${dir.path}${Platform.pathSeparator}$pageName');
    final records = await FileUtils.readJson(pageFile);
    if (records is! List) {
      if (await pageFile.exists()) {
        iLog('分页JSON损坏，跳过加载 path=${pageFile.path}');
      }
      return;
    }
    final messages = historyMessages.putIfAbsent(conversationId, () => []);
    var interrupted = false;
    for (final record in records) {
      final message = Message.fromJson(record);
      if (message == null) continue;
      message.pageName ??= pageName;
      if (messages.any((m) => m.messageId == message.messageId)) continue;
      if (_failInterruptedFileTransfer(message)) interrupted = true;
      messages.add(message);
    }
    if (interrupted) {
      await FileUtils.writeJsonAtomic(pageFile, _pageRecordsFromMemory(conversationId, pageName));
    }
  }

  /// 磁盘里读到的未完成文件传输已中断，标为失败。
  static bool _failInterruptedFileTransfer(Message message) {
    if (message is! MessageSendFileBean) return false;
    final record = message.transferRecord;
    if (record == null) return false;
    final state = FileTransferState.fromCode(record.state);
    if (state != FileTransferState.transferring && state != FileTransferState.send) return false;
    record.state = FileTransferState.failed.code;
    iLog('磁盘加载中断的文件传输，标记失败 transferId=${message.transferId} messageId=${message.messageId}');
    return true;
  }

  static Future<void> _enqueueWrite(String conversationId, Future<void> Function() action) {
    final previous = _writeQueues[conversationId] ?? Future<void>.value();
    late final Future<void> current;
    current = previous.catchError((_) {}).then((_) async {
      try {
        await action();
      } catch (e) {
        iLog('消息落盘失败 conversationId=$conversationId err=$e');
      }
    }).whenComplete(() {
      if (identical(_writeQueues[conversationId], current)) {
        _writeQueues.remove(conversationId);
      }
    });
    _writeQueues[conversationId] = current;
    return current;
  }

  static Future<ConversationIndex> _recoverIndex(String conversationId, Directory dir) async {
    final pageFiles = <File>[];
    await for (final entity in dir.list()) {
      if (entity is! File) continue;
      final name = FileUtils.fileNameOf(entity);
      if (name == 'index.json' || !name.endsWith('.json') || name.endsWith('.tmp')) continue;
      pageFiles.add(entity);
    }
    pageFiles.sort((a, b) => _pageOrder(FileUtils.fileNameOf(a)).compareTo(_pageOrder(FileUtils.fileNameOf(b))));
    final pages = <Pages>[];
    var total = 0;
    for (final file in pageFiles) {
      final records = await FileUtils.readJson(file);
      final count = records is List ? records.length : 0;
      if (records is! List) {
        iLog('分页JSON损坏，计数按0处理 path=${file.path}');
      }
      pages.add(Pages(name: FileUtils.fileNameOf(file), count: count));
      total += count;
    }
    return ConversationIndex(
      conversationId: conversationId,
      currentDir: dir.path,
      totalMessages: total,
      totalPages: pages.length,
      pages: pages,
    );
  }

  static List<dynamic> _pageRecordsFromMemory(String conversationId, String pageName) {
    final messages = historyMessages[conversationId];
    if (messages == null) return [];
    return [for (final m in messages) if (m.pageName == pageName) m.toJson()];
  }

  static int _pageOrder(String name) {
    final dot = name.lastIndexOf('.');
    final raw = dot < 0 ? name : name.substring(0, dot);
    return int.tryParse(raw) ?? 1 << 30;
  }

  /// 协议历史中是否已有该消息。
  static bool _isExists(Message message) {
    if (message.messageId.isNotEmpty) {
      final conversationId = message.base?.conversationId;
      if (conversationId != null) {
        final messages = MessageStore.historyMessages[conversationId];
        if (messages != null && messages.any((m) => m.messageId == message.messageId)) {
          return true;
        }
      } else {
        for (final messages in MessageStore.historyMessages.values) {
          if (messages.any((m) => m.messageId == message.messageId)) return true;
        }
      }
    }
    return false;
  }

  /// RFC 4122 UUID v4，例如 `550e8400-e29b-41d4-a716-446655440000`
  static String _generateUuid() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
  }
}