import 'package:flutter/material.dart';
import '../../core/supabase_client.dart';
import '../auth/login_screen.dart';

class UserHome extends StatefulWidget {
  const UserHome({super.key});

  @override
  State<UserHome> createState() => _UserHomeState();
}

class _UserHomeState extends State<UserHome> {
  int _selectedIndex = 0;

  Future<void> _logout() async {
    await supabase.auth.signOut();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  // --- LOGIC PINJAM BUKU ---
  Future<void> _borrowBook(Map<String, dynamic> book) async {
    final userId = supabase.auth.currentUser!.id;

    // Gunakan .filter untuk cek null yang aman
    final cekPinjam = await supabase
        .from('transactions')
        .select()
        .eq('user_id', userId)
        .eq('book_id', book['id'])
        .filter('return_date', 'is', null);

    if (cekPinjam.isNotEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lu masih pinjam buku ini bray, balikin dulu!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await supabase.rpc(
        'borrow_book',
        params: {'p_book_id': book['id'], 'p_user_id': userId},
      );

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Berhasil pinjam! Cek tab "Dipinjam"'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  // --- LOGIC KEMBALIKAN BUKU ---
  Future<void> _returnBook(int transactionId, int bookId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await supabase.rpc(
        'return_book',
        params: {'p_transaction_id': transactionId, 'p_book_id': bookId},
      );

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Buku berhasil dikembalikan. Terima kasih!'),
          backgroundColor: Colors.blue,
        ),
      );
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  // --- DAFTAR SEMUA BUKU ---
  Widget _buildAllBooks() {
    final booksStream = supabase
        .from('books')
        .stream(primaryKey: ['id'])
        .order('id', ascending: true);

    return StreamBuilder<List<dynamic>>(
      stream: booksStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('Perpustakaan kosong bray.'));
        }

        final books = snapshot.data!;

        return ListView.builder(
          padding: const EdgeInsets.all(10),
          itemCount: books.length,
          itemBuilder: (context, index) {
            final book = books[index] as Map<String, dynamic>;

            final title = book['title'] ?? 'Tanpa Judul';
            final stock = (book['stock'] ?? 0) as int;
            final isOutOfStock = stock < 1;

            return Card(
              child: ListTile(
                leading: Icon(
                  Icons.book,
                  color: isOutOfStock ? Colors.grey : Colors.blue,
                ),
                title: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text('Penulis: ${book['author']} | Stok: ${book['stock']}'),
                trailing: ElevatedButton(
                  onPressed: isOutOfStock ? null : () => _borrowBook(book),
                  child: Text(isOutOfStock ? 'Habis' : 'Pinjam'),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // --- BUKU YANG SEDANG DIPINJAM ---
  Widget _buildMyBooks() {
    final userId = supabase.auth.currentUser!.id;

    // FIX STREAM TYPE
    final myBooksStream = supabase
        .from('transactions')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('borrow_date', ascending: false);

    return StreamBuilder<List<dynamic>>(
      stream: myBooksStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('Belum ada riwayat pinjam.'));
        }

        // Filter manual & Casting aman
        final transactions = snapshot.data!
            .map((e) => e as Map<String, dynamic>)
            .where((t) => t['return_date'] == null)
            .toList();

        if (transactions.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.library_books_outlined,
                  size: 64,
                  color: Colors.grey,
                ),
                SizedBox(height: 10),
                Text('Gak ada buku yang lagi dipinjam.'),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(10),
          itemCount: transactions.length,
          itemBuilder: (context, index) {
            final transaction = transactions[index];
            final bookId = transaction['book_id'];

            // FORMAT TANGGAL: Cek null dulu
            final rawDate = transaction['borrow_date'] as String?;
            final displayDate = (rawDate != null && rawDate.length > 10)
                ? rawDate.substring(0, 10)
                : 'Tanggal error';

            return FutureBuilder(
              future: supabase.from('books').select().eq('id', bookId).single(),
              builder: (context, bookSnapshot) {
                if (bookSnapshot.connectionState == ConnectionState.waiting) {
                  return const Card(child: ListTile(title: Text('Loading...')));
                }

                // Handle jika buku dihapus admin (Data null/error)
                if (bookSnapshot.hasError || !bookSnapshot.hasData) {
                  return Card(
                    color: Colors.red.shade50,
                    child: ListTile(
                      title: const Text('Data Buku Hilang'),
                      subtitle: const Text(
                        'Silakan kembalikan untuk hapus list',
                      ),
                      trailing: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        onPressed: () => _returnBook(transaction['id'], bookId),
                        child: const Text(
                          'Hapus',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  );
                }

                final bookData = bookSnapshot.data!;
                final bookTitle = bookData['title'] ?? 'Judul Tidak Diketahui';

                return Card(
                  color: Colors.blue.shade50,
                  child: ListTile(
                    title: Text(
                      bookTitle,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('Dipinjam tanggal: $displayDate'),
                    trailing: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                      ),
                      onPressed: () => _returnBook(transaction['id'], bookId),
                      child: const Text(
                        'Kembalikan',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedIndex == 0 ? 'Cari Buku' : 'Buku Dipinjam'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        actions: [
          IconButton(onPressed: _logout, icon: const Icon(Icons.logout)),
        ],
      ),
      body: _selectedIndex == 0 ? _buildAllBooks() : _buildMyBooks(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Cari Buku'),
          BottomNavigationBarItem(
            icon: Icon(Icons.book_online),
            label: 'Dipinjam',
          ),
        ],
      ),
    );
  }
}
