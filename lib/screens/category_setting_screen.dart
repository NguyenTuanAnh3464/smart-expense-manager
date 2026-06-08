import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../widgets/category_icon_helper.dart';

class CategorySettingScreen extends StatelessWidget {
  static const Color primaryGreen = Color(0xFF168A36);
  static const Color softGreen = Color(0xFFEAF7EE);

  const CategorySettingScreen({super.key});

  Future<void> openCategoryDialog(
    BuildContext context, {
    QueryDocumentSnapshot<Map<String, dynamic>>? doc,
  }) async {
    final parentContext = context;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final data = doc?.data();
    final result = await showDialog<_CategoryDialogResult?>(
      context: parentContext,
      builder: (_) => _CategoryDialog(
        isEditing: doc != null,
        initialName: data?["name"]?.toString() ?? "",
        initialType: data?["type"]?.toString() ?? "expense",
        initialIconName: data?["iconName"]?.toString() ?? "category",
      ),
    );
    if (!parentContext.mounted) return;
    if (result == null) return;
    if (FirebaseAuth.instance.currentUser?.uid != user.uid) return;
    if (doc != null && doc.data()["userId"] != user.uid) {
      ScaffoldMessenger.of(parentContext).showSnackBar(
        const SnackBar(content: Text("Không có quyền sửa danh mục này")),
      );
      return;
    }

    final collection = FirebaseFirestore.instance.collection("categories");
    try {
      if (result.delete && doc != null) {
        await collection.doc(doc.id).delete();
        return;
      }
      if (!parentContext.mounted) return;

      final payload = {
        "userId": user.uid,
        "name": result.name,
        "type": result.type,
        "iconName": result.iconName,
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
    } catch (error) {
      if (!parentContext.mounted) return;
      ScaffoldMessenger.of(
        parentContext,
      ).showSnackBar(SnackBar(content: Text("Không thể lưu danh mục: $error")));
    }
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
                if (snapshot.hasError) {
                  return Center(
                    child: Text("Không thể tải danh mục: ${snapshot.error}"),
                  );
                }

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
                        leading: Icon(
                          getCategoryIcon(data["iconName"]?.toString()),
                          color: primaryGreen,
                        ),
                        title: Text(data["name"]?.toString() ?? ""),
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

class _CategoryDialog extends StatefulWidget {
  final bool isEditing;
  final String initialName;
  final String initialType;
  final String initialIconName;

  const _CategoryDialog({
    required this.isEditing,
    required this.initialName,
    required this.initialType,
    required this.initialIconName,
  });

  @override
  State<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<_CategoryDialog> {
  late final TextEditingController nameController;
  late String type;
  late String iconName;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.initialName);
    type = widget.initialType == "income" ? "income" : "expense";
    iconName = widget.initialIconName.trim().isEmpty
        ? "category"
        : widget.initialIconName.trim();
  }

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  void save() {
    final name = nameController.text.trim();
    if (name.isEmpty) return;
    Navigator.of(
      context,
    ).pop(_CategoryDialogResult(name: name, type: type, iconName: iconName));
  }

  void delete() {
    Navigator.of(context).pop(const _CategoryDialogResult.delete());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isEditing ? "Sửa danh mục" : "Thêm danh mục"),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
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
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Biểu tượng",
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 260,
                child: GridView.builder(
                  itemCount: categoryIconOptions.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemBuilder: (context, index) {
                    final option = categoryIconOptions[index];
                    final selected = option.name == iconName;
                    return InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        setState(() {
                          iconName = option.name;
                        });
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: selected
                              ? CategorySettingScreen.primaryGreen.withValues(
                                  alpha: 0.14,
                                )
                              : Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected
                                ? CategorySettingScreen.primaryGreen
                                : Colors.black12,
                            width: selected ? 2 : 1,
                          ),
                        ),
                        child: Icon(
                          option.icon,
                          color: selected
                              ? CategorySettingScreen.primaryGreen
                              : Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (widget.isEditing)
          TextButton(
            onPressed: delete,
            child: const Text("Xóa", style: TextStyle(color: Colors.red)),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text("Hủy"),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: CategorySettingScreen.primaryGreen,
            foregroundColor: Colors.white,
          ),
          onPressed: save,
          child: const Text("Lưu"),
        ),
      ],
    );
  }
}

class _CategoryDialogResult {
  final bool delete;
  final String? name;
  final String? type;
  final String? iconName;

  const _CategoryDialogResult({
    required String this.name,
    required String this.type,
    required String this.iconName,
  }) : delete = false;

  const _CategoryDialogResult.delete()
    : delete = true,
      name = null,
      type = null,
      iconName = null;
}
