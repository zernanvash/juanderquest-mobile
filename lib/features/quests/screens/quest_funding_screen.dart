import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/jdq_scaffold.dart';
import '../../../core/widgets/primary_button.dart';
import '../../auth/providers/auth_provider.dart';

class QuestFundingScreen extends ConsumerStatefulWidget {
  final String questId;
  const QuestFundingScreen({super.key,required this.questId});
  @override
  ConsumerState<QuestFundingScreen> createState()=>_QuestFundingScreenState();
}

class _QuestFundingScreenState extends ConsumerState<QuestFundingScreen>{
  final _completions=TextEditingController(text:'10');
  final _points=TextEditingController();
  Map<String,dynamic>? _plan;
  String _mode='budget';
  DateTime _starts=DateTime.now();
  DateTime _ends=DateTime.now().add(const Duration(days:14));
  bool _loading=true,_busy=false;
  String? _error,_notice;

  @override void initState(){super.initState();_load();}
  @override void dispose(){_completions.dispose();_points.dispose();super.dispose();}

  Future<void> _load() async {
    setState(()=>_loading=true);
    try{
      final response=await ref.read(apiClientProvider).dio.get('/quests/${Uri.encodeComponent(widget.questId)}/funding-plan');
      if(response.data['success']!=true)throw Exception('Could not load this funding plan.');
      setState(()=>_plan=response.data['data']['plan'] as Map<String,dynamic>?);
    }catch(error){setState(()=>_error=error.toString().replaceFirst('Exception: ',''));}
    finally{if(mounted)setState(()=>_loading=false);}
  }

  Future<void> _run(String success,Future<void> Function() action) async {
    setState(()=>_busy=true);_error=null;_notice=null;
    try{await action();if(!mounted)return;setState(()=>_notice=success);await _load();}
    catch(error){if(mounted)setState(()=>_error=error.toString().replaceFirst('Exception: ',''));}
    finally{if(mounted)setState(()=>_busy=false);}
  }

  Future<void> _create() async {
    final count=int.tryParse(_completions.text.trim());
    if(count==null||count<1){setState(()=>_error='Enter at least one planned completion.');return;}
    await _run('Draft funding round created.',() async {
      final response=await ref.read(apiClientProvider).dio.post('/quests/${Uri.encodeComponent(widget.questId)}/funding-plans',data:{
        'mode':_mode,'planned_completions':count,'starts_at':_starts.toUtc().toIso8601String(),'ends_at':_ends.toUtc().toIso8601String(),'idempotency_key':const Uuid().v4(),
      });
      if(response.data['success']!=true)throw Exception(response.data['error']?['message']??'Funding plan could not be created.');
    });
  }

  Future<void> _contribute() async {
    final points=int.tryParse(_points.text.trim());final id=_plan?['id']?.toString();
    if(points==null||points<1||id==null)return;
    await _run('Contribution recorded from your demo-point balance.',() async {
      final response=await ref.read(apiClientProvider).dio.post('/funding-plans/${Uri.encodeComponent(id)}/self-contribution',data:{'points':points,'idempotency_key':const Uuid().v4()});
      if(response.data['success']!=true)throw Exception(response.data['error']?['message']??'Contribution failed.');
      _points.clear();
    });
  }

  Future<void> _submit() async {
    final id=_plan?['id']?.toString();if(id==null)return;
    await _run('Round submitted. Sponsor matching can now continue on the web workspace.',() async {
      final response=await ref.read(apiClientProvider).dio.post('/funding-plans/${Uri.encodeComponent(id)}/submit',data:{'idempotency_key':const Uuid().v4()});
      if(response.data['success']!=true)throw Exception(response.data['error']?['message']??'Funding plan could not be submitted.');
    });
  }

  Future<void> _cancel() async {
    final id = _plan?['id']?.toString();
    if (id == null) return;
    await _run('Round cancelled and any locked points refunded.', () async {
      final response = await ref.read(apiClientProvider).dio.post(
        '/funding-plans/${Uri.encodeComponent(id)}/cancel',
        data: {'idempotency_key': const Uuid().v4()},
      );
      if (response.data['success'] != true) {
        throw Exception(response.data['error']?['message'] ?? 'Funding plan could not be cancelled.');
      }
    });
  }

  Future<void> _close() async {
    final id = _plan?['id']?.toString();
    if (id == null) return;
    await _run('Round closed. Existing traveler reward holds will still be honored.', () async {
      final response = await ref.read(apiClientProvider).dio.post(
        '/funding-plans/${Uri.encodeComponent(id)}/close',
        data: {'idempotency_key': const Uuid().v4()},
      );
      if (response.data['success'] != true) {
        throw Exception(response.data['error']?['message'] ?? 'Funding plan could not be closed.');
      }
    });
  }

  Future<void> _extend() async {
    final id = _plan?['id']?.toString();
    if (id == null) return;
    await _run('Funding window extended.', () async {
      final response = await ref.read(apiClientProvider).dio.post(
        '/funding-plans/${Uri.encodeComponent(id)}/extend',
        data: {'ends_at': _ends.toUtc().toIso8601String(), 'idempotency_key': const Uuid().v4()},
      );
      if (response.data['success'] != true) {
        throw Exception(response.data['error']?['message'] ?? 'Funding window could not be extended.');
      }
    });
  }

  Future<void> _chooseDate(bool start) async {
    final initial=start?_starts:_ends;
    final date=await showDatePicker(context:context,initialDate:initial,firstDate:DateTime.now(),lastDate:DateTime.now().add(const Duration(days:365)));
    if(date==null||!mounted)return;
    final time=await showTimePicker(context:context,initialTime:TimeOfDay.fromDateTime(initial));
    if(time==null||!mounted)return;
    final value=DateTime(date.year,date.month,date.day,time.hour,time.minute);
    setState(()=>start?_starts=value:_ends=value);
  }

  @override Widget build(BuildContext context){
    final status=_plan?['status']?.toString()??'';
    final canContribute=['draft','pending_sponsors','active'].contains(status);
    return JdqScaffold(appBar:AppBar(title:const Text('Eco-Quest funding')),body:_loading
      ?const Center(child:CircularProgressIndicator())
      :ListView(padding:const EdgeInsets.all(AppSpacing.md),children:[
        Text('Fund a real reward pool',style:AppTypography.headlineSmall),
        const SizedBox(height:AppSpacing.xs),
        Text('Demo points only. Reserved funds pay approved completions; no fiat or on-chain transfer occurs.',style:AppTypography.bodyMedium.copyWith(color:AppColors.textSecondary)),
        const SizedBox(height:AppSpacing.md),
        if(_error!=null) _MessageBox(message:_error!,error:true),
        if(_notice!=null) _MessageBox(message:_notice!,error:false),
        if(_plan==null) _createCard() else _planCard(status,canContribute),
        const SizedBox(height:AppSpacing.md),
        const _MessageBox(message:'Accepted traveler submissions keep their reward reserved while under review. Rejected proof can be resubmitted before the hold expires.',error:false),
      ]));
  }

  Widget _createCard()=>Card(child:Padding(padding:const EdgeInsets.all(AppSpacing.md),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Text('Set up this round',style:AppTypography.headlineSmall),const SizedBox(height:AppSpacing.md),
    DropdownButtonFormField<String>(value:_mode,decoration:const InputDecoration(labelText:'Funding model'),items:const [DropdownMenuItem(value:'budget',child:Text('Fixed budget — lock points up front')),DropdownMenuItem(value:'window',child:Text('Open window — reserve at attempt start'))],onChanged:_busy?null:(value)=>setState(()=>_mode=value??'budget')),
    const SizedBox(height:AppSpacing.sm),TextField(controller:_completions,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Planned completions',border:OutlineInputBorder())),
    const SizedBox(height:AppSpacing.sm),_dateButton('Starts',_starts,()=>_chooseDate(true)),_dateButton('Ends',_ends,()=>_chooseDate(false)),
    const SizedBox(height:AppSpacing.md),PrimaryButton(label:_busy?'Creating…':'Create draft funding plan',icon:Icons.savings_outlined,onPressed:_busy?null:_create),
  ])));

  Widget _planCard(String status,bool canContribute){
    final contributions=(_plan?['contributions'] as List? ?? const []).whereType<Map>().toList();
    final committed=contributions.fold<int>(0,(sum,row)=>sum+((row['committed_points'] as num?)?.toInt()??int.tryParse('${row['committed_points']}')??0));
    final held=contributions.fold<int>(0,(sum,row)=>sum+((row['held_points'] as num?)?.toInt()??int.tryParse('${row['held_points']}')??0));
    return Card(child:Padding(padding:const EdgeInsets.all(AppSpacing.md),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[const Icon(Icons.verified_outlined,color:AppColors.primary),const SizedBox(width:8),Expanded(child:Text('Funding round · ${status.replaceAll('_',' ')}',style:AppTypography.headlineSmall))]),
      const SizedBox(height:AppSpacing.sm),Text('${_plan?['reward_points']??0} points per completion · ${_plan?['mode']??_mode} model',style:AppTypography.bodyMedium),
      Text('Target ${_plan?['target_points']??0} points · $committed committed · $held currently held',style:AppTypography.bodySmall.copyWith(color:AppColors.textSecondary)),
      Text('Ends ${_dateLabel(_plan?['ends_at']?.toString())}',style:AppTypography.bodySmall.copyWith(color:AppColors.textSecondary)),
      if(canContribute)...[
        const SizedBox(height:AppSpacing.md),TextField(controller:_points,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Add your demo points',border:OutlineInputBorder())),
        const SizedBox(height:AppSpacing.sm),PrimaryButton(label:_busy?'Saving…':'Contribute points',icon:Icons.add_card,onPressed:_busy?null:_contribute),
      ],
      if(status=='draft')...[
        const SizedBox(height:AppSpacing.sm),OutlinedButton.icon(onPressed:_busy?null:_submit,icon:const Icon(Icons.send_outlined),label:const Text('Submit funding round')),
      ],
      if(['pending_sponsors','scheduled'].contains(status))...[
        const Padding(padding:EdgeInsets.only(top:12),child:Text('Use the web merchant workspace to invite sponsors. You can cancel this round here.',style:TextStyle(color:AppColors.textSecondary))),
        const SizedBox(height:AppSpacing.sm),
        SecondaryButton(label:_busy?'Cancelling…':'Cancel round and refund locked points',icon:Icons.cancel_outlined,onPressed:_busy?null:_cancel),
      ],
      if(['active','scheduled'].contains(status))...[
        const SizedBox(height:AppSpacing.sm),_dateButton('New end date',_ends,()=>_chooseDate(false)),
        const SizedBox(height:AppSpacing.sm),SecondaryButton(label:_busy?'Extending…':'Extend funding window',icon:Icons.update,onPressed:_busy?null:_extend),
      ],
      if(['active','closing'].contains(status))...[
        const SizedBox(height:AppSpacing.sm),DestructiveButton(label:_busy?'Closing…':'Close round early',icon:Icons.stop_circle_outlined,onPressed:_busy?null:_close),
      ],
    ])));
  }

  Widget _dateButton(String label,DateTime date,VoidCallback onTap)=>Padding(padding:const EdgeInsets.only(top:8),child:OutlinedButton(onPressed:_busy?null:onTap,child:Align(alignment:Alignment.centerLeft,child:Text('$label · ${_dateLabel(date.toIso8601String())}'))));
  String _dateLabel(String? raw){final date=DateTime.tryParse(raw??'');if(date==null)return 'not set';return '${date.year}-${date.month.toString().padLeft(2,'0')}-${date.day.toString().padLeft(2,'0')} ${TimeOfDay.fromDateTime(date.toLocal()).format(context)}';}
}

class _MessageBox extends StatelessWidget {
  final String message;final bool error;
  const _MessageBox({required this.message,required this.error});
  @override Widget build(BuildContext context)=>Container(margin:const EdgeInsets.only(bottom:12),padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:error?AppColors.dangerBg:AppColors.primary.withValues(alpha:.07),borderRadius:BorderRadius.circular(12)),child:Text(message,style:AppTypography.bodySmall.copyWith(color:error?AppColors.danger:AppColors.textSecondary)));
}
