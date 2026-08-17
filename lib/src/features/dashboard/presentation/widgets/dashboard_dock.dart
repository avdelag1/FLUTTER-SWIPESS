import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/providers/nav_tab_provider.dart';

class BottomNavItem {
  const BottomNavItem({required this.id, required this.wash, this.icon, this.accent = false, this.useAiIcon = false, this.label});
  final NavTab id; final Color wash; final IconData? icon; final bool accent; final bool useAiIcon; final String? label;
}

class DashboardDock extends StatefulWidget {
  const DashboardDock({super.key, required this.items, required this.selectedTab, required this.onTabSelected});
  final List<BottomNavItem> items; final NavTab? selectedTab; final ValueChanged<NavTab> onTabSelected;
  @override State<DashboardDock> createState() => _DashboardDockState();
}

class _DashboardDockState extends State<DashboardDock> {
  final ScrollController _controller = ScrollController();
  @override void initState(){super.initState();WidgetsBinding.instance.addPostFrameCallback((_)=>_revealSelected());}
  @override void didUpdateWidget(covariant DashboardDock oldWidget){super.didUpdateWidget(oldWidget);if(oldWidget.selectedTab!=widget.selectedTab){WidgetsBinding.instance.addPostFrameCallback((_)=>_revealSelected());}}
  @override void dispose(){_controller.dispose();super.dispose();}
  void _revealSelected(){
    if(!mounted||!_controller.hasClients||widget.selectedTab==null)return;
    final index=widget.items.indexWhere((item)=>item.id==widget.selectedTab);if(index<0)return;
    const itemStride=40.0;final viewport=_controller.position.viewportDimension;
    final target=(8+index*itemStride-(viewport-36)/2).clamp(0.0,_controller.position.maxScrollExtent).toDouble();
    if((_controller.offset-target).abs()<2)return;
    _controller.animateTo(target,duration:const Duration(milliseconds:260),curve:Curves.easeOutCubic);
  }
  @override Widget build(BuildContext context){
    final isLight=Theme.of(context).brightness==Brightness.light;
    return Center(child:Semantics(container:true,label:'Primary navigation',child:ConstrainedBox(
      constraints:const BoxConstraints(maxWidth:312),
      child:DecoratedBox(decoration:BoxDecoration(borderRadius:BorderRadius.circular(999),boxShadow:[BoxShadow(color:Colors.black.withAlpha(isLight?14:44),blurRadius:13,offset:const Offset(0,5))]),
        child:ClipRRect(borderRadius:BorderRadius.circular(999),child:BackdropFilter(filter:ImageFilter.blur(sigmaX:24,sigmaY:24),child:Container(
          height:48,
          decoration:BoxDecoration(
            color:isLight?Colors.white.withAlpha(132):Colors.black.withAlpha(54),
            borderRadius:BorderRadius.circular(999),
            border:Border.all(color:isLight?Colors.black.withAlpha(22):Colors.white.withAlpha(48),width:.7),
          ),
          child:ScrollConfiguration(behavior:ScrollConfiguration.of(context).copyWith(scrollbars:false,overscroll:false,dragDevices:{PointerDeviceKind.touch,PointerDeviceKind.mouse,PointerDeviceKind.trackpad,PointerDeviceKind.stylus}),child:ListView.separated(
            controller:_controller,physics:const BouncingScrollPhysics(parent:AlwaysScrollableScrollPhysics()),scrollDirection:Axis.horizontal,padding:const EdgeInsets.symmetric(horizontal:8,vertical:3),itemCount:widget.items.length,separatorBuilder:(_,__)=>const SizedBox(width:2),itemBuilder:(context,i){
              final item=widget.items[i];return DockButton(item:item,wash:item.wash,selected:widget.selectedTab==item.id,onTap:(){AppHaptics.light();widget.onTabSelected(item.id);});
            },
          )),
        ))),
      ),
    )));
  }
}

class DockButton extends StatelessWidget {
  const DockButton({super.key,required this.item,required this.wash,required this.selected,required this.onTap});
  final BottomNavItem item;final Color wash;final bool selected;final VoidCallback onTap;
  String get _label=>item.label??switch(item.id){NavTab.dashboard=>'Home',NavTab.likes=>'Likes',NavTab.ai=>'Swipess AI',NavTab.add=>'Add listing',NavTab.messages=>'Messages',NavTab.idCard=>'Virtual ID card',NavTab.seekers=>'Seekers',NavTab.filter=>'Filters',NavTab.legal=>'Lawyers and legal services',NavTab.events=>'Events'};
  @override Widget build(BuildContext context){
    final emphasized=selected||item.accent;
    final isLight=Theme.of(context).brightness==Brightness.light;
    final iconColor=isLight?Colors.black.withAlpha(emphasized?255:220):Colors.white.withAlpha(emphasized?255:232);
    return Semantics(button:true,selected:selected,label:_label,child:Tooltip(message:_label,child:Material(color:Colors.transparent,child:InkResponse(
      onTap:onTap,containedInkWell:true,highlightShape:BoxShape.circle,radius:20,splashColor:Colors.white.withAlpha(22),child:SizedBox(width:36,height:40,child:Center(child:AnimatedScale(
        scale:emphasized?1.04:1,duration:const Duration(milliseconds:150),curve:Curves.easeOutCubic,child:Stack(alignment:Alignment.center,clipBehavior:Clip.none,children:[
          if(selected)Positioned(bottom:0,child:Container(width:3.5,height:3.5,decoration:BoxDecoration(color:isLight?Colors.black.withAlpha(205):Colors.white.withAlpha(215),shape:BoxShape.circle))),
          item.useAiIcon?CustomPaint(painter:AiRobotPainter(color:iconColor),size:const Size(19,19)):Icon(item.icon??Icons.circle_outlined,size:item.accent?24:22,color:iconColor),
        ]),
      ))),
    ))));
  }
}

class AiRobotPainter extends CustomPainter {
  AiRobotPainter({required this.color});final Color color;
  @override void paint(Canvas canvas,Size size){
    final p=Paint()..color=color..style=PaintingStyle.stroke..strokeWidth=2.0..strokeCap=StrokeCap.round..strokeJoin=StrokeJoin.round;
    final s=size.shortestSide,ox=(size.width-s)/2,oy=(size.height-s)/2;
    final r=RRect.fromRectAndRadius(Rect.fromLTWH(ox+s*.17,oy+s*.33,s*.66,s*.5),Radius.circular(s*.08));canvas.drawRRect(r,p);
    canvas.drawLine(Offset(ox+s*.08,oy+s*.58),Offset(ox+s*.17,oy+s*.58),p);canvas.drawLine(Offset(ox+s*.83,oy+s*.58),Offset(ox+s*.92,oy+s*.58),p);
    canvas.drawLine(Offset(ox+s*.38,oy+s*.54),Offset(ox+s*.38,oy+s*.62),p);canvas.drawLine(Offset(ox+s*.62,oy+s*.54),Offset(ox+s*.62,oy+s*.62),p);
    canvas.drawLine(Offset(ox+s*.5,oy+s*.33),Offset(ox+s*.5,oy+s*.17),p);canvas.drawLine(Offset(ox+s*.5,oy+s*.17),Offset(ox+s*.33,oy+s*.17),p);
  }
  @override bool shouldRepaint(covariant AiRobotPainter oldDelegate)=>oldDelegate.color!=color;
}

const defaultDashboardNavItems=[
  BottomNavItem(id:NavTab.dashboard,icon:Icons.home_rounded,wash:Color(0xFFFF7A45)),
  BottomNavItem(id:NavTab.likes,icon:Icons.local_fire_department_rounded,wash:Color(0xFFE64A8A)),
  BottomNavItem(id:NavTab.ai,useAiIcon:true,wash:Color(0xFF9B7BFF)),
  BottomNavItem(id:NavTab.add,icon:Icons.add_rounded,accent:true,wash:Color(0xFFFF5A52)),
  BottomNavItem(id:NavTab.messages,icon:Icons.chat_bubble_outline_rounded,wash:Color(0xFF5B9CF6)),
  BottomNavItem(id:NavTab.idCard,icon:Icons.shield_outlined,wash:Color(0xFF8B7CF6)),
  BottomNavItem(id:NavTab.seekers,icon:Icons.people_alt_rounded,wash:Color(0xFFD96FA8)),
  BottomNavItem(id:NavTab.filter,icon:Icons.tune_rounded,wash:Color(0xFFE7A454)),
  BottomNavItem(id:NavTab.legal,icon:Icons.balance_rounded,wash:Color(0xFF7E88E8),label:'Lawyers'),
  BottomNavItem(id:NavTab.events,icon:Icons.celebration_rounded,wash:Color(0xFFE95B9B),label:'Events'),
];
