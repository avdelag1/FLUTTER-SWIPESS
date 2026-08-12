import 'package:flutter/material.dart';

class MaintenanceRequestsScreen extends StatelessWidget {
  const MaintenanceRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(child: Container(color: const Color(0xFF0A0A0D))),
          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(20),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withAlpha(40)),
                          ),
                          child: const Center(child: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20)),
                        ),
                      ),
                      const SizedBox(width: 20),
                      const Text(
                        'MAINTENANCE',
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, letterSpacing: -0.5),
                      ),
                    ],
                  ),
                ),
                
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      _buildTicket('AC Not Cooling', 'The Neo Penthouse', 'In Progress', Colors.amber),
                      const SizedBox(height: 16),
                      _buildTicket('Leaking Sink', 'Beach Villa 4', 'Resolved', Colors.green),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTicket(String issue, String location, String status, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(12),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withAlpha(100)),
        boxShadow: [BoxShadow(color: color.withAlpha(20), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(issue, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: color.withAlpha(50), borderRadius: BorderRadius.circular(999)),
                child: Text(status.toUpperCase(), style: TextStyle(color: color.shade300, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(location, style: TextStyle(color: Colors.white.withAlpha(150), fontSize: 14)),
        ],
      ),
    );
  }
}
