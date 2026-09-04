import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path_provider/path_provider.dart';
import 'package:yf_code/bean/BaseMessageBean.dart';
import 'package:yf_code/bean/ConversationIndex.dart';
import 'package:yf_code/bean/SendFileBean.dart';
import 'package:yf_code/bean/TextMessageBean.dart';
import 'package:yf_code/enum/MessageType.dart';
import 'package:yf_code/model/ConversationModel.dart';
import 'package:yf_code/model/MessageModel.dart';

class MessageStore {
  MessageStore._();
  static const _PAGE_SIZE=20;
  static final Map<String, ConversationIndex> conversationIndexMap = {};//会话id->会话index.json
  static final Map<String, List<Message>> historyMessages = {};//会话id->消息
  static final Map<String, MessageModel> conversationMessageModels = {};
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
      final conversationId = entity.path.split(Platform.pathSeparator).last;
      if (conversationId.isEmpty) continue;

      final indexFile = File('${entity.path}${Platform.pathSeparator}index.json');
      if (!await indexFile.exists()) continue;

      final json = jsonDecode(await indexFile.readAsString());
      final index = ConversationIndex.fromJson(json);
      index.currentDir = entity.path;
      conversationIndexMap[conversationId] = index;

      final pages = index.pages ?? [];
      if (pages.isEmpty) continue;
      final pageName = pages.last.name;
      if (pageName == null) continue;

      final pageFile = File('${entity.path}${Platform.pathSeparator}$pageName');
      if (!await pageFile.exists()) continue;

      final records = jsonDecode(await pageFile.readAsString()) as List<dynamic>;
      final messages = historyMessages.putIfAbsent(conversationId, () => []);
      for (final record in records) {
        final message = Message.fromJson(record);
        if (message == null) continue;
        message.pageName ??= pageName;
        if (messages.any((m) => m.messageId == message.messageId)) continue;
        messages.add(message);
      }
    }
    _syncConversations();
  }

  static String newMessageId(MessageType type) {
    return '${type.code}-${_generateUuid()}';
  }

  static void addMessage(Message message) async {
    if (_isExists(message)) return;
    final conversationId = message.base?.conversationId;
    if (conversationId == null) {
      return;
    }
    historyMessages.putIfAbsent(conversationId, () => []).add(message);
    _getConversationModel(message)?.addMessage(message);
    ConversationModel.instance.onConversation(message);

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
    if (currentDir == null || pageName == null) return;
    message.pageName = pageName;

    final pageFile = File('$currentDir${Platform.pathSeparator}$pageName');
    final List<dynamic> records;
    if (await pageFile.exists()) {
      records = jsonDecode(await pageFile.readAsString()) as List<dynamic>;
    } else {
      records = [];
    }
    records.add(message.toJson());
    await pageFile.writeAsString(jsonEncode(records));

    page.count = (page.count ?? 0) + 1;
    index.totalMessages = (index.totalMessages ?? 0) + 1;
    index.totalPages = index.pages?.length ?? 0;
    await File('$currentDir${Platform.pathSeparator}index.json').writeAsString(jsonEncode(index.toJson()));
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
    if (!await pageFile.exists()) return [];

    final records = jsonDecode(await pageFile.readAsString()) as List<dynamic>;
    final loaded = <Message>[];
    for (final record in records) {
      final message = Message.fromJson(record);
      if (message == null) continue;
      message.pageName ??= pageName;
      if (messages.any((m) => m.messageId == message.messageId)) continue;
      loaded.add(message);
    }
    messages.insertAll(0, loaded);
    return loaded;
  }

  static void onChangeMessage(Message message) async {
    final conversationId = message.base?.conversationId;
    if (conversationId == null) return;

    final messages = historyMessages[conversationId];
    if (messages != null) {
      final i = messages.indexWhere((m) => m.messageId == message.messageId);
      if (i >= 0) messages[i] = message;
    }
    conversationMessageModels[conversationId]?.onChangeMessage(message);

    final pageName = message.pageName;
    if (pageName == null) return;

    final index = await _getConversationIndex(conversationId);
    final currentDir = index.currentDir;
    if (currentDir == null) return;

    final pageFile = File('$currentDir${Platform.pathSeparator}$pageName');
    if (!await pageFile.exists()) return;

    final records = jsonDecode(await pageFile.readAsString()) as List<dynamic>;
    final recordIndex = records.indexWhere((item) {
      return item is Map && item['message_id']?.toString() == message.messageId;
    });
    if (recordIndex < 0) return;
    records[recordIndex] = message.toJson();
    await pageFile.writeAsString(jsonEncode(records));
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
      await indexFile.writeAsString(jsonEncode(index.toJson()));
    } else {
      final json = jsonDecode(await indexFile.readAsString());
      index = ConversationIndex.fromJson(json);
      index.currentDir = dir.path;
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
        if (m is TextMessageBean || m is SendFileBean) {
          last = m;
          break;
        }
      }
      last ??= messages.last;
      ConversationModel.instance.onConversation(last);
    }
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