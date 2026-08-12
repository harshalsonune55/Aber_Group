import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/estate_ops_data.dart';

/// How a manager resolved an approval request.
enum RequestOutcome {
  approved('Approved'),
  declined('Declined');

  const RequestOutcome(this.label);

  final String label;
}

/// Local, in-memory state for the Estate Ops screens.
///
/// Mirrors the design's single component state object (checked-in, task
/// completion, filters, handled approvals) as one Riverpod notifier so it
/// survives switching tabs. Once the backend exposes these modules this
/// becomes a thin view over repositories instead of held state.
class EstateOpsState {
  const EstateOpsState({
    this.checkedIn = false,
    this.doneTaskIds = const {},
    this.dealFilter = 'All',
    this.listingFilter = 'All',
    this.chequeFilter = 'Any',
    this.requestOutcomes = const {},
    this.capturedLeads = const [],
    this.loggedActivity = const {},
    this.submittedCheques = const {},
    this.bookedVisits = const {},
    this.movedStages = const {},
  });

  final bool checkedIn;
  final Set<String> doneTaskIds;
  final String dealFilter;
  final String listingFilter;
  final String chequeFilter;

  /// Leads the agent has taken down in this session, newest first.
  ///
  /// Held separately from the seeded [leads] rather than merged into one list,
  /// so it stays obvious which records came from a person and which are demo
  /// content — when the API arrives, this list is what gets posted.
  final List<Lead> capturedLeads;

  /// What the Today screen shows: what you just captured, above what was
  /// already waiting.
  List<Lead> get allLeads => [...capturedLeads, ...leads];

  /// Activity the agent has recorded against a deal in this session, keyed by
  /// deal id, newest first.
  ///
  /// A call that is logged and then vanishes is worse than one that was never
  /// logged: the agent believes the record exists. So a logged call goes into
  /// state and onto the deal's timeline in the same breath.
  final Map<String, List<ActivityEntry>> loggedActivity;

  /// A deal's timeline: what you just recorded, above its history.
  List<ActivityEntry> activityFor(Deal deal) => [
    ...?loggedActivity[deal.id],
    ...deal.activity,
  ];

  /// Cheques deposited at the bank in this session, as `dealId:label`.
  ///
  /// A post-dated cheque goes Pending → Submitted → Cleared: the agent hands
  /// it in, then the bank clears it days later. Only the middle step is the
  /// agent's to take, which is why submitting is an action here and clearing
  /// is not.
  final Set<String> submittedCheques;

  static String chequeKey(String dealId, String label) => '$dealId:$label';

  /// A cheque's status accounting for anything submitted this session.
  ///
  /// Reads through to the seed status rather than copying it, so a cheque the
  /// bank has already cleared cannot be dragged backwards to "Submitted".
  String chequeStatus(String dealId, Cheque cheque) {
    if (cheque.status != 'Pending') return cheque.status;
    return submittedCheques.contains(chequeKey(dealId, cheque.label))
        ? 'Submitted'
        : cheque.status;
  }

  /// Only a pending cheque can be handed in.
  bool canSubmitCheque(String dealId, Cheque cheque) =>
      chequeStatus(dealId, cheque) == 'Pending';

  int submittedCountFor(Deal deal) => deal.schedule
      .where((c) => chequeStatus(deal.id, c) == 'Submitted')
      .length;

  /// Viewings booked this session, keyed by listing id, newest first.
  final Map<String, List<VisitEntry>> bookedVisits;

  /// A property's visit history: what you just booked, above what happened.
  List<VisitEntry> visitsFor(Listing listing) => [
    ...?bookedVisits[listing.id],
    ...listing.visits,
  ];

  /// Deals moved to a new stage this session, keyed by deal id.
  final Map<String, String> movedStages;

  /// A deal's stage, accounting for any move made this session.
  ///
  /// Everything that shows a stage reads through here — the detail pill, the
  /// pipeline cards and the stage filter — so a moved deal cannot appear in
  /// two stages at once depending on which screen you are looking at.
  String stageOf(Deal deal) => movedStages[deal.id] ?? deal.stage;

  /// Requests the manager has already acted on, and how. The design keeps the
  /// verdict rather than a plain "handled" flag so a later undo — or the
  /// backend call that replaces this — knows which way the decision went.
  final Map<String, RequestOutcome> requestOutcomes;

  bool isHandled(String requestId) => requestOutcomes.containsKey(requestId);

  EstateOpsState copyWith({
    bool? checkedIn,
    Set<String>? doneTaskIds,
    String? dealFilter,
    String? listingFilter,
    String? chequeFilter,
    Map<String, RequestOutcome>? requestOutcomes,
    List<Lead>? capturedLeads,
    Map<String, List<ActivityEntry>>? loggedActivity,
    Set<String>? submittedCheques,
    Map<String, List<VisitEntry>>? bookedVisits,
    Map<String, String>? movedStages,
  }) {
    return EstateOpsState(
      checkedIn: checkedIn ?? this.checkedIn,
      doneTaskIds: doneTaskIds ?? this.doneTaskIds,
      dealFilter: dealFilter ?? this.dealFilter,
      listingFilter: listingFilter ?? this.listingFilter,
      chequeFilter: chequeFilter ?? this.chequeFilter,
      requestOutcomes: requestOutcomes ?? this.requestOutcomes,
      capturedLeads: capturedLeads ?? this.capturedLeads,
      loggedActivity: loggedActivity ?? this.loggedActivity,
      submittedCheques: submittedCheques ?? this.submittedCheques,
      bookedVisits: bookedVisits ?? this.bookedVisits,
      movedStages: movedStages ?? this.movedStages,
    );
  }
}

class EstateOpsNotifier extends StateNotifier<EstateOpsState> {
  EstateOpsNotifier() : super(const EstateOpsState());

  void toggleCheckedIn() => state = state.copyWith(checkedIn: !state.checkedIn);

  void toggleTask(String id) {
    final done = Set<String>.from(state.doneTaskIds);
    done.contains(id) ? done.remove(id) : done.add(id);
    state = state.copyWith(doneTaskIds: done);
  }

  void setDealFilter(String filter) =>
      state = state.copyWith(dealFilter: filter);

  void setListingFilter(String filter) =>
      state = state.copyWith(listingFilter: filter);

  void setChequeFilter(String filter) =>
      state = state.copyWith(chequeFilter: filter);

  /// Resets Inventory back to showing everything. The search box is local to
  /// the screen, so the caller clears that alongside this.
  void clearListingFilters() =>
      state = state.copyWith(listingFilter: 'All', chequeFilter: 'Any');

  /// Files a lead the agent has just taken. Newest first, because the one you
  /// are still holding a phone number for is the one you want at the top.
  void captureLead(Lead lead) {
    state = state.copyWith(capturedLeads: [lead, ...state.capturedLeads]);
  }

  /// Records something that happened on a deal — a call, for now.
  void logActivity(String dealId, ActivityEntry entry) {
    state = state.copyWith(
      loggedActivity: {
        ...state.loggedActivity,
        dealId: [entry, ...?state.loggedActivity[dealId]],
      },
    );
  }

  /// Marks a cheque as handed in to the bank, and writes it onto the deal's
  /// timeline — money moving is exactly the kind of thing someone will later
  /// need to prove happened, and when.
  void submitCheque(String dealId, Cheque cheque, {required String when}) {
    state = state.copyWith(
      submittedCheques: {
        ...state.submittedCheques,
        EstateOpsState.chequeKey(dealId, cheque.label),
      },
    );
    logActivity(dealId, (
      what: '${cheque.label} submitted — ${cheque.amount}',
      when: when,
      who: 'You',
    ));
  }

  /// Books a viewing against a listing.
  void bookVisit(String listingId, VisitEntry visit) {
    state = state.copyWith(
      bookedVisits: {
        ...state.bookedVisits,
        listingId: [visit, ...?state.bookedVisits[listingId]],
      },
    );
  }

  /// Moves a deal to a new stage, and says so on its timeline.
  ///
  /// The stage is how the pipeline is counted and how commission becomes due,
  /// so who moved it and when is worth keeping — a deal that quietly appears
  /// in Documentation is one nobody can account for.
  void moveDealStage(
    String dealId, {
    required String from,
    required String to,
    required String when,
  }) {
    state = state.copyWith(movedStages: {...state.movedStages, dealId: to});
    logActivity(dealId, (
      what: 'Stage moved — $from to $to',
      when: when,
      who: 'You',
    ));
  }

  void resolveRequest(String id, RequestOutcome outcome) {
    state = state.copyWith(
      requestOutcomes: {...state.requestOutcomes, id: outcome},
    );
  }
}

final estateOpsProvider =
    StateNotifierProvider<EstateOpsNotifier, EstateOpsState>(
      (ref) => EstateOpsNotifier(),
    );
