import 'package:flutter/material.dart';

class AddTransactionScreen extends StatefulWidget {
  final String type;
  final Map<String, dynamic>? transaction;


  const AddTransactionScreen({
    super.key,
    required this.type,
    this.transaction,
  });

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  late String selectedType;

  String selectedCategory = "Ăn uống";

  DateTime selectedDate = DateTime.now();

  final TextEditingController amountController =
  TextEditingController();

  final TextEditingController noteController =
  TextEditingController();

  final List<Map<String, dynamic>> expenseCategories = [
    {
      "name": "Ăn uống",
      "icon": Icons.restaurant,
      "color": Colors.orange
    },

    {
      "name": "Đi lại",
      "icon": Icons.directions_bus,
      "color": Colors.deepOrange
    },

    {
      "name": "Quần áo",
      "icon": Icons.checkroom,
      "color": Colors.blue
    },

    {
      "name": "Mỹ phẩm",
      "icon": Icons.brush,
      "color": Colors.pink
    },

    {
      "name": "Y tế",
      "icon": Icons.local_hospital,
      "color": Colors.green
    },

    {
      "name": "Giáo dục",
      "icon": Icons.school,
      "color": Colors.red
    },

    {
      "name": "Tiền điện",
      "icon": Icons.flash_on,
      "color": Colors.amber
    },

    {
      "name": "Tiền nhà",
      "icon": Icons.home,
      "color": Colors.brown
    },

    {
      "name": "Khác",
      "icon": Icons.more_horiz,
      "color": Colors.grey
    },
  ];

  final List<Map<String, dynamic>> incomeCategories = [
    {
      "name": "Tiền lương",
      "icon": Icons.account_balance_wallet,
      "color": Colors.green
    },

    {
      "name": "Tiền phụ cấp",
      "icon": Icons.savings,
      "color": Colors.orange
    },

    {
      "name": "Tiền thưởng",
      "icon": Icons.card_giftcard,
      "color": Colors.red
    },

    {
      "name": "Thu nhập phụ",
      "icon": Icons.monetization_on,
      "color": Colors.blue
    },

    {
      "name": "Đầu tư",
      "icon": Icons.trending_up,
      "color": Colors.teal
    },

    {
      "name": "Khác",
      "icon": Icons.more_horiz,
      "color": Colors.grey
    },
  ];

  @override
  void initState() {
    super.initState();

    if (widget.transaction != null) {
      selectedType = widget.transaction!["type"];
      selectedCategory = widget.transaction!["category"];
      amountController.text = widget.transaction!["amount"].toStringAsFixed(0);
      noteController.text = widget.transaction!["note"];
      selectedDate = widget.transaction!["date"];
    } else {
      selectedType = widget.type;
      selectedCategory = selectedType == "income" ? "Tiền lương" : "Ăn uống";
    }
  }

  List<Map<String, dynamic>> get currentCategories {
    return selectedType == "income"
        ? incomeCategories
        : expenseCategories;
  }

  Future<void> pickDate() async {
    final DateTime? pickedDate =
    await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (pickedDate != null) {
      setState(() {
        selectedDate = pickedDate;
      });
    }
  }

  void changeType(String type) {
    setState(() {
      selectedType = type;

      selectedCategory =
      type == "income"
          ? "Tiền lương"
          : "Ăn uống";
    });
  }

  @override
  Widget build(BuildContext context) {
    bool isIncome = selectedType == "income";

    return Scaffold(
      backgroundColor: Colors.green[50],

      appBar: AppBar(
        backgroundColor: Colors.green,
        elevation: 0,

        iconTheme:
        const IconThemeData(color: Colors.white),

        title: const Text(
          "Thêm giao dịch",

          style: TextStyle(
            color: Colors.white,
          ),
        ),
      ),

      body: SingleChildScrollView(
        child: Column(
          children: [

            const SizedBox(height: 10),

            Container(
              margin:
              const EdgeInsets.symmetric(
                horizontal: 24,
              ),

              padding: const EdgeInsets.all(4),

              decoration: BoxDecoration(
                color: Colors.white,

                borderRadius:
                BorderRadius.circular(12),
              ),

              child: Row(
                children: [

                  Expanded(
                    child: typeButton(
                      "expense",
                      "Tiền chi",
                    ),
                  ),

                  Expanded(
                    child: typeButton(
                      "income",
                      "Tiền thu",
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            Container(
              color: Colors.white,

              padding: const EdgeInsets.all(16),

              child: Column(
                children: [

                  rowItem(
                    title: "Ngày",

                    child: InkWell(
                      onTap: pickDate,

                      child: Text(
                        "${selectedDate.day}/${selectedDate.month}/${selectedDate.year}",

                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 22,
                          fontWeight:
                          FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  const Divider(
                    color: Colors.black12,
                  ),

                  rowItem(
                    title: "Ghi chú",

                    child: TextField(
                      controller:
                      noteController,

                      style:
                      const TextStyle(
                        color:
                        Colors.black87,
                      ),

                      decoration:
                      const InputDecoration(
                        hintText:
                        "Chưa nhập vào",

                        hintStyle:
                        TextStyle(
                          color:
                          Colors.black38,
                        ),

                        border:
                        InputBorder.none,
                      ),
                    ),
                  ),

                  const Divider(
                    color: Colors.black12,
                  ),

                  rowItem(
                    title: isIncome
                        ? "Tiền thu"
                        : "Tiền chi",

                    child: TextField(
                      controller:
                      amountController,

                      keyboardType:
                      TextInputType.number,

                      style:
                      const TextStyle(
                        color:
                        Colors.black87,

                        fontSize: 28,

                        fontWeight:
                        FontWeight.bold,
                      ),

                      decoration:
                      const InputDecoration(
                        hintText: "0",

                        hintStyle:
                        TextStyle(
                          color:
                          Colors.black38,
                        ),

                        border:
                        InputBorder.none,

                        suffixText: "đ",

                        suffixStyle:
                        TextStyle(
                          color:
                          Colors.black87,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  const Align(
                    alignment:
                    Alignment.centerLeft,

                    child: Text(
                      "Danh mục",

                      style: TextStyle(
                        color:
                        Colors.black87,

                        fontSize: 22,

                        fontWeight:
                        FontWeight.bold,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  GridView.builder(
                    shrinkWrap: true,

                    physics:
                    const NeverScrollableScrollPhysics(),

                    itemCount:
                    currentCategories.length,

                    gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,

                      mainAxisSpacing: 12,

                      crossAxisSpacing: 12,

                      childAspectRatio: 1.25,
                    ),

                    itemBuilder:
                        (context, index) {

                      final category =
                      currentCategories[index];

                      final isSelected =
                          selectedCategory ==
                              category["name"];

                      return InkWell(
                        onTap: () {
                          setState(() {
                            selectedCategory =
                            category["name"];
                          });
                        },

                        child: Container(
                          decoration:
                          BoxDecoration(
                            color:
                            Colors.white,

                            borderRadius:
                            BorderRadius.circular(
                                10),

                            border: Border.all(
                              color: isSelected
                                  ? Colors.green
                                  : Colors.black12,

                              width: isSelected
                                  ? 2.5
                                  : 1,
                            ),
                          ),

                          child: Column(
                            mainAxisAlignment:
                            MainAxisAlignment
                                .center,

                            children: [

                              Icon(
                                category["icon"],

                                color:
                                category["color"],

                                size: 32,
                              ),

                              const SizedBox(
                                  height: 8),

                              Text(
                                category["name"],

                                textAlign:
                                TextAlign.center,

                                style:
                                const TextStyle(
                                  color: Colors
                                      .black87,

                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            Padding(
              padding:
              const EdgeInsets.symmetric(
                horizontal: 24,
              ),

              child: SizedBox(
                width: double.infinity,
                height: 58,

                child: ElevatedButton(
                  style:
                  ElevatedButton.styleFrom(
                    backgroundColor:
                    Colors.green,

                    shape:
                    RoundedRectangleBorder(
                      borderRadius:
                      BorderRadius.circular(
                          30),
                    ),
                  ),

                  onPressed: () {
                    if (amountController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Vui lòng nhập số tiền"),
                        ),
                      );
                      return;
                    }

                    final transaction = {
                      "category": selectedCategory,
                      "amount": double.parse(amountController.text),
                      "note": noteController.text,
                      "type": selectedType,
                      "date": selectedDate,
                    };

                    Navigator.pop(context, transaction);
                  },

                  child: Text(
                    isIncome
                        ? "Nhập khoản thu"
                        : "Nhập khoản chi",

                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget typeButton(
      String type,
      String title,
      ) {
    bool isSelected =
        selectedType == type;

    return GestureDetector(
      onTap: () => changeType(type),

      child: Container(
        padding:
        const EdgeInsets.symmetric(
          vertical: 12,
        ),

        decoration: BoxDecoration(
          color: isSelected
              ? Colors.green
              : Colors.transparent,

          borderRadius:
          BorderRadius.circular(10),
        ),

        child: Center(
          child: Text(
            title,

            style: TextStyle(
              color: isSelected
                  ? Colors.white
                  : Colors.green,

              fontSize: 18,

              fontWeight:
              FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget rowItem({
    required String title,
    required Widget child,
  }) {
    return Row(
      children: [

        SizedBox(
          width: 100,

          child: Text(
            title,

            style: const TextStyle(
              color: Colors.black87,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        Expanded(child: child),
      ],
    );
  }
}