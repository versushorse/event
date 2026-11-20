// 「💮 行ったよ！」思い出スタンプ編集ダイアログ ＆ 写真添付・サムネイル・拡大ビューア共通ウィジェット
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/outing_spot.dart';

/// 1スポットあたりに保存できる思い出写真の最大枚数
const int kMaxVisitedPhotosPerSpot = 4;

/// クラウド同期やローカル保存を圧迫しないための1枚あたりバイト上限（約480KB）
const int kMaxPhotoBytes = 480 * 1024;

/// Base64（data URI含む）またはネットワークURLを安全にデコードして表示する画像ウィジェット
class SafeMemoryOrNetworkImage extends StatelessWidget {
  final String source;
  final BoxFit fit;
  final double? width;
  final double? height;

  const SafeMemoryOrNetworkImage({
    super.key,
    required this.source,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
  });

  static Uint8List? tryDecodeBase64Image(String raw) {
    try {
      final commaIdx = raw.indexOf('base64,');
      final b64 = commaIdx >= 0 ? raw.substring(commaIdx + 7) : raw;
      return base64Decode(b64.trim());
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (source.startsWith('http://') || source.startsWith('https://')) {
      return Image.network(
        source,
        fit: fit,
        width: width,
        height: height,
        errorBuilder: (_, _, _) => _buildFallbackBox(),
      );
    }
    final bytes = tryDecodeBase64Image(source);
    if (bytes == null || bytes.isEmpty) {
      return _buildFallbackBox();
    }
    return Image.memory(
      bytes,
      fit: fit,
      width: width,
      height: height,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => _buildFallbackBox(),
    );
  }

  Widget _buildFallbackBox() {
    return Container(
      width: width,
      height: height,
      color: Colors.grey.shade200,
      alignment: Alignment.center,
      child: Icon(Icons.broken_image_outlined, color: Colors.grey.shade500),
    );
  }
}

/// 添付写真をタップしたときに開く全画面プレビュー（ピンチズーム＆スワイプ切替対応）
void showVisitedPhotoViewerDialog(
  BuildContext context, {
  required List<String> photos,
  int initialIndex = 0,
  String? title,
}) {
  if (photos.isEmpty) return;
  final controller = PageController(
    initialPage: initialIndex.clamp(0, photos.length - 1),
  );
  int currentPage = initialIndex.clamp(0, photos.length - 1);

  showDialog<void>(
    context: context,
    builder: (dialogCtx) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            backgroundColor: Colors.black,
            insetPadding: const EdgeInsets.all(12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: [
                  SizedBox(
                    width: MediaQuery.of(context).size.width * 0.92,
                    height: MediaQuery.of(context).size.height * 0.72,
                    child: PageView.builder(
                      controller: controller,
                      itemCount: photos.length,
                      onPageChanged: (idx) =>
                          setDialogState(() => currentPage = idx),
                      itemBuilder: (context, idx) {
                        return InteractiveViewer(
                          minScale: 0.8,
                          maxScale: 4.0,
                          child: Center(
                            child: SafeMemoryOrNetworkImage(
                              source: photos[idx],
                              fit: BoxFit.contain,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Positioned(
                    top: 10,
                    left: 12,
                    right: 12,
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            '${title != null ? "$title " : ""}${currentPage + 1} / ${photos.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const Spacer(),
                        IconButton.filled(
                          style: IconButton.styleFrom(
                            backgroundColor:
                                Colors.black.withValues(alpha: 0.6),
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () => Navigator.of(dialogCtx).pop(),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

/// カード内に並べるコンパクトな写真ギャラリー（タップで拡大表示・任意で追加ボタン付き）
class VisitedPhotoGallery extends StatelessWidget {
  final List<String> photos;
  final String? spotTitle;
  final VoidCallback? onAddPhotoTap;

  const VisitedPhotoGallery({
    super.key,
    required this.photos,
    this.spotTitle,
    this.onAddPhotoTap,
  });

  @override
  Widget build(BuildContext context) {
    if (photos.isEmpty && onAddPhotoTap == null) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 76,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (int i = 0; i < photos.length; i++)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => showVisitedPhotoViewerDialog(
                    context,
                    photos: photos,
                    initialIndex: i,
                    title: spotTitle,
                  ),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: SizedBox(
                          width: 92,
                          height: 76,
                          child: SafeMemoryOrNetworkImage(
                            source: photos[i],
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      Positioned(
                        right: 4,
                        bottom: 4,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(
                            Icons.zoom_in,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (onAddPhotoTap != null &&
                photos.length < kMaxVisitedPhotosPerSpot)
              InkWell(
                onTap: onAddPhotoTap,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 84,
                  height: 76,
                  decoration: BoxDecoration(
                    color: Colors.deepOrange.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.deepOrange.shade200,
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_a_photo_outlined,
                        size: 20,
                        color: Colors.deepOrange.shade700,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        photos.isEmpty ? '写真を追加' : 'さらに追加',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepOrange.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 💮 行ったよ！の思い出メモ＆写真アルバムを表示する共通ボックス
class VisitedMemoryBox extends StatelessWidget {
  final OutingSpot spot;
  final VoidCallback? onEditTap;

  const VisitedMemoryBox({
    super.key,
    required this.spot,
    this.onEditTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasPhotosOrAction = spot.visitedPhotos.isNotEmpty || onEditTap != null;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.deepOrange.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.deepOrange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('💮', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  spot.visitedMemory.isEmpty
                      ? 'お出かけ達成！（${spot.visitedDate} / ${"★" * spot.visitedRating}）'
                      : '思い出（${spot.visitedDate}）: ${spot.visitedMemory}',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.deepOrange.shade900,
                  ),
                ),
              ),
              if (onEditTap != null)
                TextButton(
                  onPressed: onEditTap,
                  child: const Text('編集'),
                ),
            ],
          ),
          if (hasPhotosOrAction) ...[
            const SizedBox(height: 8),
            VisitedPhotoGallery(
              photos: spot.visitedPhotos,
              spotTitle: spot.title,
              onAddPhotoTap: onEditTap,
            ),
          ],
        ],
      ),
    );
  }
}

/// 💮 行ったよ！思い出スタンプ ＆ 写真添付 共通ダイアログ
void showVisitedStampEditorDialog({
  required BuildContext context,
  required OutingSpot spot,
  required ValueChanged<OutingSpot> onSave,
  ImagePicker? imagePicker,
}) {
  final now = DateTime.now();
  final defaultDate = spot.visitedDate.isNotEmpty
      ? spot.visitedDate
      : '${now.year}/${now.month}/${now.day}';
  final dateCtrl = TextEditingController(text: defaultDate);
  final memoryCtrl = TextEditingController(text: spot.visitedMemory);
  final picker = imagePicker ?? ImagePicker();

  int rating = spot.visitedRating.clamp(1, 5);
  bool isVisited = true;
  final photos = List<String>.from(spot.visitedPhotos);
  bool isPickingPhoto = false;
  String? photoWarning;

  Future<void> addPickedFiles(
    List<XFile> files,
    void Function(VoidCallback) setDialogState,
  ) async {
    if (files.isEmpty) return;
    int skippedTooLarge = 0;
    for (final file in files) {
      if (photos.length >= kMaxVisitedPhotosPerSpot) break;
      try {
        final bytes = await file.readAsBytes();
        if (bytes.isEmpty) continue;
        if (bytes.length > kMaxPhotoBytes) {
          skippedTooLarge++;
          continue;
        }
        final b64 = base64Encode(bytes);
        final ext = file.name.toLowerCase().endsWith('.png') ? 'png' : 'jpeg';
        final dataUri = 'data:image/$ext;base64,$b64';
        if (!photos.contains(dataUri)) {
          photos.add(dataUri);
        }
      } catch (_) {}
    }
    setDialogState(() {
      isPickingPhoto = false;
      photoWarning = skippedTooLarge > 0
          ? '※サイズが大きすぎる画像（480KB超）は自動保護のためスキップされました'
          : null;
    });
  }

  Future<void> pickFromGallery(
    void Function(VoidCallback) setDialogState,
  ) async {
    if (photos.length >= kMaxVisitedPhotosPerSpot) return;
    setDialogState(() {
      isPickingPhoto = true;
      photoWarning = null;
    });
    try {
      final picked = await picker.pickMultiImage(
        maxWidth: 720,
        maxHeight: 720,
        imageQuality: 55,
      );
      await addPickedFiles(picked, setDialogState);
    } catch (_) {
      setDialogState(() {
        isPickingPhoto = false;
        photoWarning = 'アルバムから写真を読み込めませんでした';
      });
    }
  }

  Future<void> pickFromCamera(
    void Function(VoidCallback) setDialogState,
  ) async {
    if (photos.length >= kMaxVisitedPhotosPerSpot) return;
    setDialogState(() {
      isPickingPhoto = true;
      photoWarning = null;
    });
    try {
      final file = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 720,
        maxHeight: 720,
        imageQuality: 55,
      );
      await addPickedFiles(file != null ? [file] : const [], setDialogState);
    } catch (_) {
      setDialogState(() {
        isPickingPhoto = false;
        photoWarning = 'カメラを起動できませんでした';
      });
    }
  }

  showDialog<void>(
    context: context,
    builder: (dialogCtx) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text('💮「${spot.title}」行ったよ記録'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('💮 行ったよ！スタンプを押す',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    value: isVisited,
                    onChanged: (v) => setDialogState(() => isVisited = v),
                  ),
                  TextField(
                    controller: dateCtrl,
                    decoration: InputDecoration(
                      labelText: 'お出かけした日',
                      hintText: '例: 2026/11/08',
                      border: const OutlineInputBorder(),
                      isDense: true,
                      suffixIcon: IconButton(
                        tooltip: 'カレンダーから選ぶ',
                        icon: const Icon(Icons.calendar_today, size: 18),
                        onPressed: () async {
                          final pickedDate = await showDatePicker(
                            context: context,
                            initialDate: now,
                            firstDate: DateTime(2020),
                            lastDate: now.add(const Duration(days: 365)),
                          );
                          if (pickedDate != null) {
                            dateCtrl.text =
                                '${pickedDate.year}/${pickedDate.month}/${pickedDate.day}';
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text('家族の満足度:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (idx) {
                      final starVal = idx + 1;
                      return IconButton(
                        onPressed: () => setDialogState(() => rating = starVal),
                        icon: Icon(
                          starVal <= rating ? Icons.star : Icons.star_border,
                          color: Colors.amber.shade700,
                          size: 30,
                        ),
                      );
                    }),
                  ),
                  TextField(
                    controller: memoryCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: '思い出ひとことメモ（任意）',
                      hintText: '例: 子どもがすごく楽しそうだった！また来年も行きたい',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Text(
                        '📸 思い出写真',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '（${photos.length}/$kMaxVisitedPhotosPerSpot枚・自動軽量化）',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (photos.isNotEmpty) ...[
                    SizedBox(
                      height: 84,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (int idx = 0; idx < photos.length; idx++)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Stack(
                                  children: [
                                    GestureDetector(
                                      onTap: () => showVisitedPhotoViewerDialog(
                                        context,
                                        photos: photos,
                                        initialIndex: idx,
                                        title: spot.title,
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: SizedBox(
                                          width: 84,
                                          height: 84,
                                          child: SafeMemoryOrNetworkImage(
                                            source: photos[idx],
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      top: 2,
                                      right: 2,
                                      child: InkWell(
                                        onTap: () => setDialogState(() {
                                          photos.removeAt(idx);
                                        }),
                                        child: Container(
                                          padding: const EdgeInsets.all(3),
                                          decoration: const BoxDecoration(
                                            color: Colors.black54,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.close,
                                            size: 14,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (photos.length < kMaxVisitedPhotosPerSpot)
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        OutlinedButton.icon(
                          onPressed: isPickingPhoto
                              ? null
                              : () => pickFromGallery(setDialogState),
                          icon: isPickingPhoto
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.photo_library_outlined,
                                  size: 17),
                          label: const Text('アルバムから追加',
                              style: TextStyle(fontSize: 12)),
                        ),
                        OutlinedButton.icon(
                          onPressed: isPickingPhoto
                              ? null
                              : () => pickFromCamera(setDialogState),
                          icon: const Icon(Icons.camera_alt_outlined, size: 17),
                          label: const Text('カメラで撮影',
                              style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  if (photoWarning != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      photoWarning!,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(),
                child: const Text('キャンセル'),
              ),
              FilledButton(
                onPressed: () {
                  final updated = spot.copyWith(
                    isVisited: isVisited,
                    visitedDate: isVisited ? dateCtrl.text.trim() : '',
                    visitedRating: rating,
                    visitedMemory: isVisited ? memoryCtrl.text.trim() : '',
                    visitedPhotos: isVisited ? List.unmodifiable(photos) : const [],
                  );
                  onSave(updated);
                  Navigator.of(dialogCtx).pop();
                },
                child: const Text('保存する'),
              ),
            ],
          );
        },
      );
    },
  );
}
