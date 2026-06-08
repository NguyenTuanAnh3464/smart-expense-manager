import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/bank_extracted_transaction.dart';
import '../services/bank_ocr_service.dart';
import 'bank_transaction_review_screen.dart';

class BankImageUploadScreen extends StatefulWidget {
  const BankImageUploadScreen({super.key});

  @override
  State<BankImageUploadScreen> createState() => _BankImageUploadScreenState();
}

class _BankImageUploadScreenState extends State<BankImageUploadScreen> {
  static const Color primaryGreen = Color(0xFF168A36);

  final ImagePicker picker = ImagePicker();
  final BankOcrService ocrService = BankOcrService();

  final List<XFile> selectedImages = [];
  bool isAnalyzing = false;
  String? errorMessage;

  Future<void> pickImagesFromGallery() async {
    try {
      final images = await picker.pickMultiImage(imageQuality: 85);
      if (!mounted || images.isEmpty) return;
      setState(() {
        selectedImages.addAll(images);
        errorMessage = null;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Không thể chọn ảnh: $error")),
      );
    }
  }

  Future<void> pickImageFromCamera() async {
    try {
      final image = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (!mounted || image == null) return;
      setState(() {
        selectedImages.add(image);
        errorMessage = null;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Không thể chụp ảnh: $error")),
      );
    }
  }

  Future<Uint8List> readPreviewBytes(XFile image) {
    return image.readAsBytes();
  }

  Future<void> analyzeImages() async {
    if (selectedImages.isEmpty || isAnalyzing) return;

    setState(() {
      isAnalyzing = true;
      errorMessage = null;
    });

    try {
      final parsedTransactions = <BankExtractedTransaction>[];
      var imagesWithoutTransactions = 0;

      for (final image in selectedImages) {
        final rawText = await ocrService.extractTextFromImage(image.path);
        final transactions = ocrService.parseBankTransactions(rawText);
        if (transactions.isEmpty) {
          _debugPrintOcrText(rawText);
          imagesWithoutTransactions++;
        } else {
          parsedTransactions.addAll(transactions);
        }
      }

      if (!mounted) return;
      if (parsedTransactions.isEmpty) {
        setState(() {
          errorMessage = "Không tìm thấy giao dịch có đủ ngày và số tiền.";
        });
        return;
      }

      final deduplicated = _deduplicateTransactions(parsedTransactions);
      final warnings = <String>[
        "OCR local có thể đọc sai thông tin. Vui lòng kiểm tra kỹ trước khi lưu.",
        if (imagesWithoutTransactions > 0)
          "$imagesWithoutTransactions ảnh không có giao dịch đủ ngày và số tiền.",
        if (deduplicated.duplicateCount > 0)
          "Đã bỏ qua ${deduplicated.duplicateCount} giao dịch có thể bị trùng.",
      ];

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => BankTransactionReviewScreen(
            transactions: deduplicated.transactions,
            warnings: warnings,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      debugPrint("BankImageUpload OCR error: $error");
      setState(() {
        errorMessage =
            "Không đọc được nội dung trong ảnh. Vui lòng thử ảnh khác hoặc nhập thủ công.";
      });
    } finally {
      if (mounted) {
        setState(() {
          isAnalyzing = false;
        });
      }
    }
  }

  void _debugPrintOcrText(String rawText) {
    debugPrint("BankImageUpload OCR raw text was not parsed:");
    const chunkSize = 800;
    for (var start = 0; start < rawText.length; start += chunkSize) {
      final end = (start + chunkSize).clamp(0, rawText.length);
      debugPrint(rawText.substring(start, end));
    }
  }

  _DedupResult _deduplicateTransactions(
    List<BankExtractedTransaction> transactions,
  ) {
    final seen = <String>{};
    final unique = <BankExtractedTransaction>[];
    var duplicateCount = 0;

    for (final transaction in transactions) {
      final date = transaction.date ?? DateTime.now();
      final key = [
        date.year,
        date.month,
        date.day,
        transaction.amount.round(),
        transaction.type,
      ].join(":");
      if (seen.add(key)) {
        unique.add(transaction);
      } else {
        duplicateCount++;
      }
    }

    return _DedupResult(
      transactions: unique,
      duplicateCount: duplicateCount,
    );
  }

  void removeImageAt(int index) {
    setState(() {
      selectedImages.removeAt(index);
      errorMessage = null;
    });
  }

  void clearImages() {
    setState(() {
      selectedImages.clear();
      errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasImages = selectedImages.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Quét ảnh giao dịch"),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!hasImages) ...[
            _PickCard(
              icon: Icons.photo_library_outlined,
              title: "Chọn ảnh từ thư viện",
              onTap: pickImagesFromGallery,
            ),
            const SizedBox(height: 12),
            _PickCard(
              icon: Icons.photo_camera_outlined,
              title: "Chụp ảnh từ camera",
              onTap: pickImageFromCamera,
            ),
          ] else ...[
            Text(
              "Đã chọn ${selectedImages.length} ảnh",
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: selectedImages.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.15,
              ),
              itemBuilder: (context, index) {
                final image = selectedImages[index];
                return _ImagePreviewTile(
                  image: image,
                  readPreviewBytes: readPreviewBytes,
                  onRemove: isAnalyzing ? null : () => removeImageAt(index),
                );
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isAnalyzing ? null : pickImagesFromGallery,
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: const Text("Chọn thêm ảnh"),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isAnalyzing ? null : clearImages,
                    icon: const Icon(Icons.close),
                    label: const Text("Hủy"),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: isAnalyzing ? null : analyzeImages,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: isAnalyzing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.document_scanner_outlined),
              label: Text(isAnalyzing ? "Đang phân tích..." : "Phân tích ảnh"),
            ),
          ],
          if (errorMessage != null) ...[
            const SizedBox(height: 14),
            Text(errorMessage!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 16),
          Text(
            "Ảnh ngân hàng có thể chứa dữ liệu nhạy cảm. App chỉ dùng OCR local trên thiết bị để đọc ảnh và không gửi ảnh lên Cloud Function.",
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(
                alpha: 0.68,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ImagePreviewTile extends StatelessWidget {
  final XFile image;
  final Future<Uint8List> Function(XFile image) readPreviewBytes;
  final VoidCallback? onRemove;

  const _ImagePreviewTile({
    required this.image,
    required this.readPreviewBytes,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        fit: StackFit.expand,
        children: [
          FutureBuilder<Uint8List>(
            future: readPreviewBytes(image),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const ColoredBox(
                  color: Color(0xFFEDEDED),
                  child: Center(child: Text("Không thể xem ảnh")),
                );
              }
              if (!snapshot.hasData) {
                return const ColoredBox(
                  color: Color(0xFFEDEDED),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              return Image.memory(snapshot.data!, fit: BoxFit.cover);
            },
          ),
          Positioned(
            top: 6,
            right: 6,
            child: Material(
              color: Colors.black.withValues(alpha: 0.55),
              shape: const CircleBorder(),
              child: IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.close, color: Colors.white, size: 18),
                tooltip: "Xóa ảnh",
                constraints: const BoxConstraints.tightFor(
                  width: 34,
                  height: 34,
                ),
                padding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PickCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _PickCard({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF168A36), size: 30),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _DedupResult {
  final List<BankExtractedTransaction> transactions;
  final int duplicateCount;

  const _DedupResult({
    required this.transactions,
    required this.duplicateCount,
  });
}
