import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CategorySettingScreen extends StatelessWidget {
  static const Color primaryGreen = Color(0xFF168A36);
  static const Color softGreen = Color(0xFFEAF7EE);

  const CategorySettingScreen({super.key});

  Future<void> openCategoryDialog(
    BuildContext context, {
    QueryDocumentSnapshot<Map<String, dynamic>>? doc,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final data = doc?.data();
    final nameController = TextEditingController(text: data?["name"] ?? "");
    var type = data?["type"]?.toString() ?? "expense";

    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(doc == null ? "Thêm danh mục" : "Sửa danh mục"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: "Tên danh mục",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: "expense", label: Text("Tiền chi")),
                      ButtonSegment(value: "income", label: Text("Tiền thu")),
                    ],
                    selected: {type},
                    onSelectionChanged: (value) {
                      setState(() {
                        type = value.first;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                if (doc != null)
                  TextButton(
                    onPressed: () =>
                        Navigator.pop(dialogContext, {"delete": true}),
                    child: const Text(
                      "Xóa",
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text("Hủy"),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryGreen,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    final name = nameController.text.trim();
                    if (name.isEmpty) return;
                    Navigator.pop(dialogContext, {"name": name, "type": type});
                  },
                  child: const Text("Lưu"),
                ),
              ],
            );
          },
        );
      },
    );
    nameController.dispose();
    if (!context.mounted) return;
    if (result == null) return;

    final collection = FirebaseFirestore.instance.collection("categories");
    if (result["delete"] == true && doc != null) {
      await collection.doc(doc.id).delete();
      if (!context.mounted) return;
      return;
    }

    final payload = {
      "userId": user.uid,
      "name": result["name"],
      "type": result["type"],
      "iconName": "more_horiz",
      "color": primaryGreen.toARGB32(),
      "updatedAt": FieldValue.serverTimestamp(),
    };

    if (doc == null) {
      await collection.add({
        ...payload,
        "createdAt": FieldValue.serverTimestamp(),
      });
    } else {
      await collection.doc(doc.id).update(payload);
    }
    if (!context.mounted) return;
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: softGreen,
      appBar: AppBar(
        title: const Text("Danh mục"),
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => openCategoryDialog(context),
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
      body: user == null
          ? const Center(child: Text("Chưa đăng nhập"))
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection("categories")
                  .where("userId", isEqualTo: user.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return const Center(
                    child: Text(
                      "Chưa có danh mục tùy chỉnh",
                      style: TextStyle(color: Colors.black54),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data();
                    return Card(
                      color: Colors.white,
                      child: ListTile(
                        leading: const Icon(
                          Icons.category,
                          color: primaryGreen,
                        ),
                        title: Text(data["name"] ?? ""),
                        subtitle: Text(
                          data["type"] == "income" ? "Tiền thu" : "Tiền chi",
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => openCategoryDialog(context, doc: doc),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
