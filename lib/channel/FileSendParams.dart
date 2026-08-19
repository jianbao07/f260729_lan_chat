
/// 发送文件时供外部构建信令消息所需的参数。
class FileSendParams {
  FileSendParams({
    required this.mimeType,
    required this.name,
    required this.totalSize,
    required this.port,
    required this.localPath,
  });

  final String mimeType;
  final String name;
  final int totalSize;
  final int port;
  final String localPath;
}