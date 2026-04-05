import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_page.dart';

final supabase = Supabase.instance.client;

class HomePage extends StatefulWidget {
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List expenses = [];
  List filteredExpenses = [];

  final titleController = TextEditingController();
  final amountController = TextEditingController();
  final searchController = TextEditingController();

  bool isLoading = true;
  bool isSaving = false;
  String sortType = 'latest';
  String selectedCategory = 'Food';

  final List<String> categories = [
    'Food',
    'Travel',
    'Shopping',
    'Bills',
    'Health',
    'Education',
    'Entertainment',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    fetchExpenses();
    searchController.addListener(applyFilters);
  }

  double getTotal() {
    double total = 0;
    for (var item in filteredExpenses) {
      total += double.tryParse(item['amount'].toString()) ?? 0;
    }
    return total;
  }

  Future<void> fetchExpenses() async {
    try {
      if (mounted) {
        setState(() => isLoading = true);
      }

      final user = supabase.auth.currentUser;
      if (user == null) return;

      final data = await supabase
          .from('expenses')
          .select()
          .eq('user_id', user.id);

      if (!mounted) return;

      setState(() {
        expenses = data;
      });

      applyFilters();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Fetch failed: $e")));
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> addExpense() async {
    final title = titleController.text.trim();
    final amount = amountController.text.trim();
    final user = supabase.auth.currentUser;

    if (title.isEmpty || amount.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter title and amount")),
      );
      return;
    }

    if (double.tryParse(amount) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Amount must be a valid number")),
      );
      return;
    }

    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("User not logged in")));
      return;
    }

    try {
      setState(() => isSaving = true);

      await supabase.from('expenses').insert({
        'user_id': user.id,
        'title': title,
        'amount': double.parse(amount),
        'category': selectedCategory,
      }).select();

      titleController.clear();
      amountController.clear();
      selectedCategory = 'Food';

      if (!mounted) return;

      Navigator.pop(context);
      await fetchExpenses();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Expense saved successfully")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Save failed: $e")));
    } finally {
      if (mounted) {
        setState(() => isSaving = false);
      }
    }
  }

  Future<void> deleteExpense(dynamic id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Expense"),
        content: const Text("Are you sure you want to delete this expense?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final deletedRows = await supabase
          .from('expenses')
          .delete()
          .eq('id', id)
          .select();

      if (!mounted) return;

      await fetchExpenses();

      if (deletedRows.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Expense deleted successfully")),
        );
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Delete failed")));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Delete failed: $e")));
    }
  }

  Future<void> editExpense(dynamic item) async {
    final editTitleController = TextEditingController(text: item['title']);
    final editAmountController = TextEditingController(
      text: item['amount'].toString(),
    );
    String editCategory = (item['category'] ?? 'Other').toString();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                10,
                20,
                MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Edit Expense",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: editTitleController,
                    decoration: const InputDecoration(
                      labelText: "Title",
                      prefixIcon: Icon(Icons.title),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: editAmountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: "Amount",
                      prefixIcon: Icon(Icons.currency_rupee),
                    ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    value: categories.contains(editCategory)
                        ? editCategory
                        : 'Other',
                    decoration: const InputDecoration(
                      labelText: "Category",
                      prefixIcon: Icon(Icons.category_outlined),
                    ),
                    items: categories
                        .map(
                          (category) => DropdownMenuItem(
                            value: category,
                            child: Text(category),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setModalState(() {
                        editCategory = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 18),
                  ElevatedButton(
                    onPressed: () async {
                      final newTitle = editTitleController.text.trim();
                      final newAmount = editAmountController.text.trim();

                      if (newTitle.isEmpty || newAmount.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Please fill all fields"),
                          ),
                        );
                        return;
                      }

                      if (double.tryParse(newAmount) == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Enter valid amount")),
                        );
                        return;
                      }

                      try {
                        await supabase
                            .from('expenses')
                            .update({
                              'title': newTitle,
                              'amount': double.parse(newAmount),
                              'category': editCategory,
                            })
                            .eq('id', item['id'])
                            .select();

                        if (!mounted) return;

                        Navigator.pop(context);
                        await fetchExpenses();

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Expense updated")),
                        );
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Update failed: $e")),
                        );
                      }
                    },
                    child: const Text("Update Expense"),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void applyFilters() {
    List temp = List.from(expenses);

    final query = searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      temp = temp.where((item) {
        final title = item['title'].toString().toLowerCase();
        final amount = item['amount'].toString().toLowerCase();
        final category = (item['category'] ?? '').toString().toLowerCase();

        return title.contains(query) ||
            amount.contains(query) ||
            category.contains(query);
      }).toList();
    }

    if (sortType == 'title') {
      temp.sort(
        (a, b) => a['title'].toString().compareTo(b['title'].toString()),
      );
    } else if (sortType == 'amount_high') {
      temp.sort((a, b) {
        final aAmount = double.tryParse(a['amount'].toString()) ?? 0;
        final bAmount = double.tryParse(b['amount'].toString()) ?? 0;
        return bAmount.compareTo(aAmount);
      });
    } else if (sortType == 'amount_low') {
      temp.sort((a, b) {
        final aAmount = double.tryParse(a['amount'].toString()) ?? 0;
        final bAmount = double.tryParse(b['amount'].toString()) ?? 0;
        return aAmount.compareTo(bAmount);
      });
    }

    setState(() {
      filteredExpenses = temp;
    });
  }

  void logout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("Are you sure you want to logout?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Logout"),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      await supabase.auth.signOut();

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => LoginPage()),
        (route) => false,
      );
    }
  }

  void showAddExpenseSheet() {
    titleController.clear();
    amountController.clear();
    selectedCategory = 'Food';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                10,
                20,
                MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "Add Expense",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: "Title",
                        prefixIcon: Icon(Icons.title),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: "Amount",
                        prefixIcon: Icon(Icons.currency_rupee),
                      ),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      value: selectedCategory,
                      decoration: const InputDecoration(
                        labelText: "Category",
                        prefixIcon: Icon(Icons.category_outlined),
                      ),
                      items: categories
                          .map(
                            (category) => DropdownMenuItem(
                              value: category,
                              child: Text(category),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setModalState(() {
                          selectedCategory = value!;
                        });
                      },
                    ),
                    const SizedBox(height: 18),
                    ElevatedButton(
                      onPressed: isSaving ? null : addExpense,
                      child: isSaving
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text("Save Expense"),
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

  Widget buildSummaryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xff0f766e), Color(0xff14b8a6)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.teal.withOpacity(.2),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Total Expenses",
            style: TextStyle(color: Colors.white70, fontSize: 15),
          ),
          const SizedBox(height: 10),
          Text(
            "Rs. ${getTotal().toStringAsFixed(2)}",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "${filteredExpenses.length} item(s)",
            style: const TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Color getCategoryColor(String category) {
    switch (category) {
      case 'Food':
        return Colors.orange;
      case 'Travel':
        return Colors.blue;
      case 'Shopping':
        return Colors.purple;
      case 'Bills':
        return Colors.red;
      case 'Health':
        return Colors.green;
      case 'Education':
        return Colors.indigo;
      case 'Entertainment':
        return Colors.pink;
      default:
        return Colors.grey;
    }
  }

  Widget buildExpenseCard(dynamic item) {
    final amount = double.tryParse(item['amount'].toString()) ?? 0;
    final category = (item['category'] ?? 'Other').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.teal.withOpacity(.12),
            child: const Icon(Icons.payments_outlined, color: Colors.teal),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['title'].toString(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),

                const SizedBox(height: 6),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    category,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "Rs. ${amount.toStringAsFixed(2)}",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),

              const SizedBox(height: 6),

              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, size: 20, color: Colors.teal),
                    onPressed: () => editExpense(item),
                  ),

                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      size: 20,
                      color: Colors.red,
                    ),
                    onPressed: () => deleteExpense(item['id']),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    titleController.dispose();
    amountController.dispose();
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userEmail = supabase.auth.currentUser?.email ?? "User";
    final userName = userEmail.contains('@')
        ? userEmail.split('@')[0]
        : userEmail;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Expense Tracker"),
        centerTitle: false,
        actions: [
          IconButton(onPressed: fetchExpenses, icon: const Icon(Icons.refresh)),
          IconButton(onPressed: logout, icon: const Icon(Icons.logout)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: showAddExpenseSheet,
        label: const Text("Add"),
        icon: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: fetchExpenses,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text("Hello,", style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 4),
            Text(
              "Hi $userName",
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            buildSummaryCard(),
            const SizedBox(height: 18),
            TextField(
              controller: searchController,
              decoration: const InputDecoration(
                hintText: "Search title, amount, category",
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: sortType,
              decoration: const InputDecoration(labelText: "Sort"),
              items: const [
                DropdownMenuItem(value: 'latest', child: Text("Default")),
                DropdownMenuItem(value: 'title', child: Text("Title")),
                DropdownMenuItem(
                  value: 'amount_high',
                  child: Text("Amount: High to Low"),
                ),
                DropdownMenuItem(
                  value: 'amount_low',
                  child: Text("Amount: Low to High"),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  sortType = value!;
                });
                applyFilters();
              },
            ),
            const SizedBox(height: 18),
            if (isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 50),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (filteredExpenses.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Column(
                  children: [
                    Icon(
                      Icons.receipt_long_outlined,
                      size: 60,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 12),
                    Text(
                      "No expenses found",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      "Tap the Add button to create your first expense",
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              ...filteredExpenses
                  .map((item) => buildExpenseCard(item))
                  .toList(),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }
}
