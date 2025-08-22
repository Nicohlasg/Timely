import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/event_proposal.dart';
import '../state/proposal_state.dart';
import '../widgets/background_container.dart';

class ProposalsInboxPage extends StatelessWidget {
  const ProposalsInboxPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BackgroundImageContainer(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text('Event Proposals', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: Consumer<ProposalState>(
          builder: (context, proposalState, child) {
            final proposals = proposalState.proposals
                .where((p) => p.status == 'pending')
                .toList()
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

            if (proposalState.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (proposals.isEmpty) {
              return Center(
                child: Text('You have no new event proposals.', style: GoogleFonts.inter(color: Colors.white70)),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: proposals.length,
              itemBuilder: (context, index) {
                return _ProposalCard(proposal: proposals[index]);
              },
            );
          },
        ),
      ),
    );
  }
}

class _ProposalCard extends StatelessWidget {
  final EventProposal proposal;
  const _ProposalCard({required this.proposal});

  @override
  Widget build(BuildContext context) {
    final proposalState = context.read<ProposalState>();
    final formattedDate = DateFormat.yMMMEd().format(proposal.start.toDate());
    final formattedTime = "${DateFormat.jm().format(proposal.start.toDate())} - ${DateFormat.jm().format(proposal.end.toDate())}";

    return Card(
      color: Colors.white.withValues(alpha: 0.15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PROPOSAL FROM ${proposal.proposerName.toUpperCase()}',
              style: GoogleFonts.inter(
                color: Colors.cyan.shade300,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(proposal.title, style: GoogleFonts.inter(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(formattedDate, style: GoogleFonts.inter(color: Colors.white70, fontSize: 14)),
            Text(formattedTime, style: GoogleFonts.inter(color: Colors.white70, fontSize: 14)),
            if (proposal.location.isNotEmpty)
              Text('At: ${proposal.location}', style: GoogleFonts.inter(color: Colors.white70, fontSize: 14)),
            const Divider(height: 24, color: Colors.white30),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => proposalState.respondToProposal(proposalId: proposal.id, accept: false),
                  child: Text('Decline', style: GoogleFonts.inter(color: Colors.red.shade300)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => proposalState.respondToProposal(proposalId: proposal.id, accept: true),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  child: Text('Accept', style: GoogleFonts.inter()),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}