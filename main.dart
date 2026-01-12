import 'package:flutter/material.dart';
import 'dart:async';

void main() {
  runApp(const PokerStackApp());
}

/* =========================
   MODELS
========================= */

class Player {
  final int id;
  final String name;
  int chips;
  int currentBet;
  bool hasFolded;

  Player({
    required this.id,
    required this.name,
    required this.chips,
    this.currentBet = 0,
    this.hasFolded = false,
  });

  void reset() {
    currentBet = 0;
    hasFolded = false;
  }
}

class GameState {
  List<Player> players;
  int pot = 0;
  int smallBlind;
  int bigBlind;
  int dealerIndex = 0;
  int sbIndex = 0;
  int bbIndex = 1;

  GameState({
    required this.players,
    required this.smallBlind,
    required this.bigBlind,
  });

  void rotateBlinds() {
    dealerIndex = (dealerIndex + 1) % players.length;
    sbIndex = (dealerIndex + 1) % players.length;
    bbIndex = (dealerIndex + 2) % players.length;
  }

  void resetRound() {
    pot = 0;
    for (var p in players) {
      p.reset();
    }
    rotateBlinds();
  }
}

/* =========================
   APP ROOT
========================= */

class PokerStackApp extends StatelessWidget {
  const PokerStackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PokerStack',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const SetupScreen(),
    );
  }
}

/* =========================
   SETUP SCREEN
========================= */

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  int playerCount = 2;
  int startingChips = 1000;
  int smallBlind = 10;
  int bigBlind = 20;

  final List<TextEditingController> controllers = [];

  @override
  void initState() {
    super.initState();
    _updateControllers();
  }

  void _updateControllers() {
    controllers.clear();
    for (int i = 0; i < playerCount; i++) {
      controllers.add(TextEditingController(text: "Player ${i + 1}"));
    }
  }

  void startGame() {
    final players = List.generate(playerCount, (i) {
      return Player(
        id: i,
        name: controllers[i].text,
        chips: startingChips,
      );
    });

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GameScreen(
          game: GameState(
            players: players,
            smallBlind: smallBlind,
            bigBlind: bigBlind,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("PokerStack Setup")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            DropdownButton<int>(
              value: playerCount,
              items: List.generate(9, (i) => i + 2)
                  .map((v) => DropdownMenuItem(
                        value: v,
                        child: Text("$v Players"),
                      ))
                  .toList(),
              onChanged: (v) {
                setState(() {
                  playerCount = v!;
                  _updateControllers();
                });
              },
            ),
            ...controllers.map((c) => TextField(
                  controller: c,
                  decoration:
                      const InputDecoration(labelText: "Player Name"),
                )),
            TextField(
              decoration:
                  const InputDecoration(labelText: "Starting Chips"),
              keyboardType: TextInputType.number,
              onChanged: (v) =>
                  startingChips = int.tryParse(v) ?? startingChips,
            ),
            TextField(
              decoration: const InputDecoration(labelText: "Small Blind"),
              keyboardType: TextInputType.number,
              onChanged: (v) =>
                  smallBlind = int.tryParse(v) ?? smallBlind,
            ),
            TextField(
              decoration: const InputDecoration(labelText: "Big Blind"),
              keyboardType: TextInputType.number,
              onChanged: (v) =>
                  bigBlind = int.tryParse(v) ?? bigBlind,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: startGame,
              child: const Text("Start Game"),
            )
          ],
        ),
      ),
    );
  }
}

/* =========================
   GAME SCREEN
========================= */

class GameScreen extends StatefulWidget {
  final GameState game;
  const GameScreen({super.key, required this.game});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  Timer? timer;
  int timeLeft = 0;

  void startTimer() {
    timer?.cancel();
    setState(() => timeLeft = 15);

    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() => timeLeft--);
      if (timeLeft <= 0) t.cancel();
    });
  }

  void bet(Player p) async {
    int betAmount = 0;

    await showModalBottomSheet(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setModal) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Slider(
                min: 0,
                max: p.chips.toDouble(),
                value: betAmount.toDouble(),
                divisions: p.chips == 0 ? 1 : p.chips,
                label: betAmount.toString(),
                onChanged: (v) => setModal(() {
                  betAmount = v.toInt();
                }),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  ElevatedButton(
                    child: const Text("Fold"),
                    onPressed: () {
                      setState(() => p.hasFolded = true);
                      Navigator.pop(context);
                    },
                  ),
                  ElevatedButton(
                    child: const Text("Bet"),
                    onPressed: () {
                      setState(() {
                        p.chips -= betAmount;
                        p.currentBet += betAmount;
                        widget.game.pot += betAmount;
                      });
                      Navigator.pop(context);
                    },
                  ),
                ],
              )
            ],
          );
        },
      ),
    );
  }

  void finishRound() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Select Winner"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: widget.game.players.map((p) {
            return ListTile(
              title: Text(p.name),
              onTap: () {
                setState(() {
                  p.chips += widget.game.pot;
                  widget.game.resetRound();
                });
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void showAIDealer() {
    showDialog(
      context: context,
      builder: (_) => const AlertDialog(
        title: Text("AI Dealer Assistant"),
        content: Text(
          "• Call = match highest bet\n"
          "• Raise = increase bet\n"
          "• Fold = exit round\n"
          "• Blinds rotate each round\n"
          "• Pot goes to winner\n\n"
          "Tip: Watch your chip count!",
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.game;

    return Scaffold(
      appBar: AppBar(
        title: const Text("PokerStack"),
        actions: [
          IconButton(
            icon: const Icon(Icons.smart_toy),
            onPressed: showAIDealer,
          )
        ],
      ),
      body: Column(
        children: [
          Text("Pot: ${g.pot}", style: const TextStyle(fontSize: 22)),
          Text(
              "SB: ${g.players[g.sbIndex].name}  BB: ${g.players[g.bbIndex].name}"),
          if (timeLeft > 0) Text("Timer: $timeLeft"),
          Expanded(
            child: ListView(
              children: g.players.map((p) {
                return Card(
                  color: p.hasFolded
                      ? Colors.grey[800]
                      : Colors.grey[900],
                  child: ListTile(
                    title: Text(p.name),
                    subtitle:
                        Text("Chips: ${p.chips} | Bet: ${p.currentBet}"),
                    trailing: IconButton(
                      icon: const Icon(Icons.timer),
                      onPressed: startTimer,
                    ),
                    onTap: () => bet(p),
                  ),
                );
              }).toList(),
            ),
          ),
          ElevatedButton(
            onPressed: finishRound,
            child: const Text("Finish Round"),
          ),
        ],
      ),
    );
  }
}
