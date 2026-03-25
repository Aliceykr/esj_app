import 'package:flutter/material.dart';
import '../models/novel.dart';

class NovelCard extends StatelessWidget {
  final Novel novel;
  final VoidCallback? onTap;

  const NovelCard({super.key, required this.novel, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: novel.coverUrl.isNotEmpty
                  ? Image.network(
                      novel.coverUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      // 防盗链：esjzone.cc 图片服务器校验 Referer
                      headers: const {'Referer': 'https://www.esjzone.cc/'},
                      // 移除 cacheWidth/cacheHeight：该参数在华为设备上触发 FlutterImageDecoder
                      // 导致 WebP 格式解码失败（'unimplemented'），改由系统原生解码器处理
                      errorBuilder: (context, err, stack) => Container(
                        color: Colors.grey[200],
                        child: const Icon(Icons.book, size: 40, color: Colors.grey),
                      ),
                    )
                  : Container(
                      color: Colors.grey[200],
                      child: const Icon(Icons.book, size: 40, color: Colors.grey),
                    ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            novel.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          if (novel.author.isNotEmpty)
            Text(
              novel.author,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
        ],
      ),
    );
  }
}
