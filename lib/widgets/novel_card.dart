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
                      errorBuilder: (context, err, stack) => _placeholder(
                        icon: Icons.broken_image_outlined,
                        label: '无法加载',
                        color: Colors.orange[100]!,
                      ),
                    )
                  : _placeholder(
                      icon: Icons.image_not_supported_outlined,
                      label: '无封面',
                      color: Colors.grey[200]!,
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

  Widget _placeholder({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: color,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 32, color: Colors.grey[500]),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}
