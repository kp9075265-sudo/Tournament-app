import 'dart:math';
import 'package:flutter/material.dart';

void main() {
  runApp(TournamentApp());
}

class TournamentApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tournament App Demo',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
      ),
      home: HomeScreen(),
    );
  }
}

// Simple in-memory "database" models
class User {
  String id;
  String name;
  String email;
  int wallet;
  User({required this.id, required this.name, required this.email, this.wallet = 0});
}

class Tournament {
  String id;
  String title;
  String ownerId;
  int entryFee;
  List<String> players;
  Tournament({required this.id, required this.title, required this.ownerId, this.entryFee = 0, List<String>? players})
      : players = players ?? [];
}

// App State (very simple)
class AppState extends ChangeNotifier {
  User? currentUser;
  final Map<String, User> users = {};
  final Map<String, Tournament> tournaments = {};

  void register(String name, String email) {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final u = User(id: id, name: name, email: email, wallet: 100); // start with 100 coins
    users[id] = u;
    currentUser = u;
    notifyListeners();
  }

  void createTournament(String title, int fee) {
    if (currentUser == null) return;
    final id = Random().nextInt(1000000).toString();
    final t = Tournament(id: id, title: title, ownerId: currentUser!.id, entryFee: fee);
    tournaments[id] = t;
    notifyListeners();
  }

  String? joinTournament(String tournamentId) {
    if (currentUser == null) return 'Login required';
    final t = tournaments[tournamentId];
    if (t == null) return 'Tournament not found';
    if (t.players.contains(currentUser!.id)) return 'Already joined';
    // Payment simulation: deduct entry fee from wallet
    if (currentUser!.wallet < t.entryFee) return 'Insufficient wallet balance';
    currentUser!.wallet -= t.entryFee;
    t.players.add(currentUser!.id);
    notifyListeners();
    return null; // success
  }
}

final appState = AppState();

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Tournament App Demo'),
        actions: [
          IconButton(
            icon: Icon(Icons.person),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen()));
            },
          )
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          children: [
            RegistrationCard(),
            SizedBox(height: 12),
            Expanded(child: TournamentListCard(onCreate: () => setState(() {}))),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.add),
        onPressed: () async {
          final result = await showDialog<Map<String, dynamic>>(
            context: context,
            builder: (_) => CreateTournamentDialog(),
          );
          if (result != null && result['title'] != null) {
            appState.createTournament(result['title'], result['fee']);
            setState(() {});
          }
        },
      ),
    );
  }
}

class RegistrationCard extends StatefulWidget {
  @override
  _RegistrationCardState createState() => _RegistrationCardState();
}

class _RegistrationCardState extends State<RegistrationCard> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(12),
        child: appState.currentUser == null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Register / Login', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  TextField(controller: _nameCtrl, decoration: InputDecoration(labelText: 'Name')),
                  TextField(controller: _emailCtrl, decoration: InputDecoration(labelText: 'Email')),
                  SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () {
                      final name = _nameCtrl.text.trim();
                      final email = _emailCtrl.text.trim();
                      if (name.isEmpty || email.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Provide name & email')));
                        return;
                      }
                      setState(() {
                        appState.register(name, email);
                      });
                    },
                    child: Text('Register'),
                  )
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Hello, ${appState.currentUser!.name}'),
                  Text('Wallet: ${appState.currentUser!.wallet}'),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        appState.currentUser = null;
                      });
                    },
                    child: Text('Logout'),
                  )
                ],
              ),
      ),
    );
  }
}

class TournamentListCard extends StatefulWidget {
  final VoidCallback onCreate;
  TournamentListCard({required this.onCreate});
  @override
  _TournamentListCardState createState() => _TournamentListCardState();
}

class _TournamentListCardState extends State<TournamentListCard> {
  @override
  Widget build(BuildContext context) {
    final list = appState.tournaments.values.toList();
    if (list.isEmpty) {
      return Card(
        child: Center(child: Padding(padding: EdgeInsets.all(20), child: Text('No tournaments yet. Create one!'))),
      );
    }
    return ListView.builder(
      itemCount: list.length,
      itemBuilder: (_, idx) {
        final t = list[idx];
        return Card(
          child: ListTile(
            title: Text(t.title),
            subtitle: Text('Entry: ${t.entryFee} • Players: ${t.players.length}'),
            trailing: ElevatedButton(
              child: Text(t.players.contains(appState.currentUser?.id) ? 'Joined' : 'Join'),
              onPressed: t.players.contains(appState.currentUser?.id)
                  ? null
                  : () async {
                      // Payment flow -> either call real gateway or the mock handler below
                      final err = await _handleJoin(t);
                      if (err != null) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
                      } else {
                        setState(() {});
                      }
                    },
            ),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => TournamentDetailScreen(tournament: t)));
            },
          ),
        );
      },
    );
  }

  Future<String?> _handleJoin(Tournament t) async {
    // If entry fee is 0, just join
    if (t.entryFee == 0) {
      return appState.joinTournament(t.id);
    }
    // Here you can either:
    // - Use in-app wallet (already implemented) which deducts wallet coin
    // - Or launch real payment gateway (Razorpay / Stripe)
    // Mock payment: Offer choice
    final choice = await showDialog<int>(
        context: context,
        builder: (_) => SimpleDialog(
              title: Text('Payment'),
              children: [
                SimpleDialogOption(child: Text('Pay with Wallet (balance: ${appState.currentUser?.wallet ?? 0})'), onPressed: () => Navigator.pop(context, 1)),
                SimpleDialogOption(child: Text('Pay with Gateway (Razorpay / UPI)'), onPressed: () => Navigator.pop(context, 2)),
                SimpleDialogOption(child: Text('Cancel'), onPressed: () => Navigator.pop(context, 0)),
              ],
            ));
    if (choice == 1) {
      return appState.joinTournament(t.id);
    } else if (choice == 2) {
      // Placeholder for real payment:
      // call startPayment(amount: t.entryFee, onSuccess: ..., onError: ...)
      final success = await Navigator.push(context, MaterialPageRoute(builder: (_) => MockPaymentScreen(amount: t.entryFee)));
      if (success == true) {
        return appState.joinTournament(t.id);
      } else {
        return 'Payment failed or canceled';
      }
    } else {
      return 'Cancelled';
    }
  }
}

class CreateTournamentDialog extends StatefulWidget {
  @override
  _CreateTournamentDialogState createState() => _CreateTournamentDialogState();
}

class _CreateTournamentDialogState extends State<CreateTournamentDialog> {
  final _title = TextEditingController();
  final _fee = TextEditingController(text: '0');
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Create Tournament'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: _title, decoration: InputDecoration(labelText: 'Title')),
          TextField(controller: _fee, decoration: InputDecoration(labelText: 'Entry Fee (integer)'), keyboardType: TextInputType.number),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
        ElevatedButton(
            onPressed: () {
              final title = _title.text.trim();
              final fee = int.tryParse(_fee.text.trim()) ?? 0;
              if (title.isEmpty) return;
              Navigator.pop(context, {'title': title, 'fee': fee});
            },
            child: Text('Create'))
      ],
    );
  }
}

class TournamentDetailScreen extends StatelessWidget {
  final Tournament tournament;
  TournamentDetailScreen({required this.tournament});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tournament.title)),
      body: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Entry Fee: ${tournament.entryFee}'),
            SizedBox(height: 8),
            Text('Players (${tournament.players.length}):'),
            ...tournament.players.map((id) {
              final u = appState.users[id];
              return ListTile(title: Text(u?.name ?? 'Player'));
            }).toList(),
            SizedBox(height: 12),
            Text('Bracket (simple pairing):'),
            Expanded(child: _buildBracket(tournament)),
          ],
        ),
      ),
    );
  }

  Widget _buildBracket(Tournament t) {
    final players = t.players.map((id) => appState.users[id]?.name ?? 'Player').toList();
    if (players.isEmpty) return Center(child: Text('No players yet'));
    return ListView.builder(
        itemCount: (players.length / 2).ceil(),
        itemBuilder: (context, idx) {
          final a = players.length > idx * 2 ? players[idx * 2] : 'TBD';
          final b = players.length > idx * 2 + 1 ? players[idx * 2 + 1] : 'TBD';
          return ListTile(
            leading: Text('Match ${idx + 1}'),
            title: Text('$a  vs  $b'),
          );
        });
  }
}

class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final user = appState.currentUser;
    return Scaffold(
      appBar: AppBar(title: Text('Profile')),
      body: Padding(
        padding: EdgeInsets.all(12),
        child: user == null
            ? Center(child: Text('Not logged in'))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Name: ${user.name}'),
                  Text('Email: ${user.email}'),
                  Text('Wallet: ${user.wallet}'),
                  SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () {
                      // top-up wallet (mock)
                      user.wallet += 100;
                      setState(() {});
                    },
                    child: Text('Top-up Wallet (+100)'),
                  ),
                  SizedBox(height: 12),
                  Text('Registered Tournaments:'),
                  ...appState.tournaments.values.where((t) => t.players.contains(user.id)).map((t) => ListTile(title: Text(t.title))).toList(),
                ],
              ),
      ),
    );
  }
}

class MockPaymentScreen extends StatefulWidget {
  final int amount;
  MockPaymentScreen({required this.amount});
  @override
  _MockPaymentScreenState createState() => _MockPaymentScreenState();
}

class _MockPaymentScreenState extends State<MockPaymentScreen> {
  bool processing = true;
  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(seconds: 2), () {
      setState(() {
        processing = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Mock Payment')),
      body: Center(
        child: processing
            ? Column(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(), SizedBox(height: 8), Text('Processing payment...')])
            : Column(mainAxisSize: MainAxisSize.min, children: [
                Text('Pretend payment of ${widget.amount} succeeded.'),
                SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text('Return (Success)'),
                ),
                SizedBox(height: 8),
                TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel')),
              ]),
      ),
    );
  }
}

// NOTE: To integrate real Razorpay (or other gateway), add razorpay_flutter plugin and call it here.
// Example (pseudo):
//
// void startPayment({required int amount}) {
//   var options = {
//     'key': 'YOUR_KEY_HERE',
//     'amount': amount * 100, // in paise
//     'name': 'Tournament Entry',
//     'description': 'Entry fee',
//     'prefill': {'contact': '9123456789', 'email': appState.currentUser?.email ?? ''},
//   };
//   _razorpay.open(options);
// }
//
// Handle payment success and then call appState.joinTournament(t.id)
//
