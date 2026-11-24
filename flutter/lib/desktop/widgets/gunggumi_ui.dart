// 궁구미 원격: 고객 화면 B안(구미 안내형)
// 시안: https://claude.ai/artifact/3bgxoMjNvYMgXspx5z3zkc
// 화면: 첫 화면(GgHomePanel) / 연결 허용(GgApproveView) / 연결 중(GgConnectedView) / 끝난 화면(GgEndedView)
// 첫 화면은 받기 전용(conn-type=incoming) 홈 화면에, 연결 중·끝난 화면은 연결 관리(CM) 창에 쓴다.

import 'dart:async';
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_hbb/models/peer_model.dart';
import 'package:flutter_hbb/models/platform_model.dart';

class GgColors {
  static const bg = Color(0xFF111318);
  static const card = Color(0xFF1C1F26);
  static const line = Color(0xFF2B303B);
  static const text = Color(0xFFE9ECF2);
  static const sub = Color(0xFF9AA3B2);
  static const accent = Color(0xFF3FB27F);
  static const danger = Color(0xFFE0524A);
}

const ggPhone = '1833-8107';

/// 연결이 허용된 뒤 연결 관리 창을 3초 뒤 자동 최소화하던 원래 동작을 끔
const kGunggumiKeepCmVisible = true;
const ggWidth = 400.0;

/// 끝난 화면을 보여 줄지(연결이 끝난 뒤 CM 창이 저절로 숨거나 닫히지 않게 함)
class GgSession {
  static int? endedSeconds;
  static int lastSeconds = 0;
  static bool get showingEnded => endedSeconds != null;
  static void started() {
    endedSeconds = null;
    lastSeconds = 0;
  }

  static void ended() {
    endedSeconds ??= lastSeconds;
  }
}

const _shieldSvg =
    '<svg viewBox="0 0 24 24" fill="none" stroke="#3fb27f" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" xmlns="http://www.w3.org/2000/svg"><path d="M12 3l8 3v6c0 5-3.5 8-8 9-4.5-1-8-4-8-9V6z"/><path d="M8.5 12l2.5 2.5 4.5-5"/></svg>';

const _gumiSvg =
    '<svg viewBox="0 0 64 64" xmlns="http://www.w3.org/2000/svg"><path d="M32 12v-5" stroke="#2A2E36" stroke-width="2.2" stroke-linecap="round"/><circle cx="32" cy="6" r="2.6" fill="#3FB37F"/><ellipse cx="32" cy="59" rx="15" ry="2.4" fill="#000" opacity=".28"/><rect x="14" y="13" width="36" height="44" rx="18" fill="#E2C58E" stroke="#2A2E36" stroke-width="2.2"/><path d="M20 24q2-5 8-6" fill="none" stroke="#fff" stroke-width="2" stroke-linecap="round" opacity=".5"/><path d="M20.6 35.2q3.4-4.4 6.8 0" fill="none" stroke="#2A2E36" stroke-width="2.2" stroke-linecap="round"/><path d="M36.6 35.2q3.4-4.4 6.8 0" fill="none" stroke="#2A2E36" stroke-width="2.2" stroke-linecap="round"/><path d="M28 41q4 3.6 8 0" fill="none" stroke="#2A2E36" stroke-width="2.1" stroke-linecap="round"/><path d="M19 57v3M45 57v3" stroke="#2A2E36" stroke-width="2.4" stroke-linecap="round"/></svg>';

const _checkSvg =
    '<svg viewBox="0 0 24 24" fill="none" stroke="#3fb27f" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" xmlns="http://www.w3.org/2000/svg"><circle cx="12" cy="12" r="9"/><path d="M8 12.5l2.7 2.7L16 9.8"/></svg>';

TextStyle _t(double size,
        {FontWeight w = FontWeight.w400, Color c = GgColors.text}) =>
    TextStyle(
        fontSize: size,
        fontWeight: w,
        color: c,
        letterSpacing: -0.2,
        height: 1.35,
        decoration: TextDecoration.none);

/// "482913" → "482 913", "114834422" → "114 834 422" (숫자이고 길이가 3의 배수일 때만)
String ggGroup3(String s) {
  final t = s.replaceAll(' ', '');
  if (t.length >= 6 && t.length % 3 == 0 && RegExp(r'^\d+$').hasMatch(t)) {
    final parts = <String>[];
    for (var i = 0; i < t.length; i += 3) {
      parts.add(t.substring(i, i + 3));
    }
    return parts.join(' ');
  }
  return t;
}

String ggDuration(int seconds) {
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;
  String two(int v) => v.toString().padLeft(2, '0');
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
}

class GgHeader extends StatelessWidget {
  const GgHeader({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
      child: Row(children: [
        SvgPicture.string(_shieldSvg, width: 22, height: 22),
        const SizedBox(width: 10),
        Text('궁구미 원격', style: _t(15, w: FontWeight.w700)),
      ]),
    );
  }
}

/// 단계 막대: 1 번호 알려 주기 → 2 연결 허용 → 3 기사님이 해결. step: 1~3, 4 = 모두 끝남
class GgStepBar extends StatelessWidget {
  final int step;
  const GgStepBar({Key? key, required this.step}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    const labels = ['1 번호 알려 주기', '2 연결 허용', '3 기사님이 해결'];
    return Row(
      children: List.generate(3, (i) {
        final n = i + 1;
        final reached = n <= step;
        final current = n == step;
        return Expanded(
          child: Opacity(
            opacity: reached && !current && step <= 3 ? 0.55 : 1,
            child: Padding(
              padding: EdgeInsets.only(right: i < 2 ? 6 : 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 5,
                    decoration: BoxDecoration(
                        color: reached ? GgColors.accent : GgColors.line,
                        borderRadius: BorderRadius.circular(3)),
                  ),
                  const SizedBox(height: 6),
                  Text(labels[i],
                      style: _t(12,
                          w: current ? FontWeight.w800 : FontWeight.w700,
                          c: reached ? GgColors.text : GgColors.sub)),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}

/// 구미 말풍선
class GgBubble extends StatelessWidget {
  final List<InlineSpan> spans;
  const GgBubble({Key? key, required this.spans}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Semantics(
          label: 'PC 친구 구미',
          child: SvgPicture.string(_gumiSvg, width: 76, height: 76),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: GgColors.card,
              border: Border.all(color: GgColors.line),
              borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                  bottomLeft: Radius.circular(4)),
            ),
            child: Text.rich(TextSpan(style: _t(14.5), children: spans)),
          ),
        ),
      ],
    );
  }
}

TextSpan _b(String s) =>
    TextSpan(text: s, style: const TextStyle(fontWeight: FontWeight.w800));

class GgCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const GgCard(
      {Key? key,
      required this.child,
      this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 20)})
      : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: GgColors.card,
        border: Border.all(color: GgColors.line),
        borderRadius: BorderRadius.circular(22),
      ),
      child: child,
    );
  }
}

class GgButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback? onPressed;
  const GgButton(
      {Key? key,
      required this.label,
      this.color = GgColors.accent,
      required this.onPressed})
      : super(key: key);
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Text(label,
            style: _t(16, w: FontWeight.w800, c: Colors.white)),
      ),
    );
  }
}

Widget _footNote(List<InlineSpan> spans) => Text.rich(
      TextSpan(style: _t(12.5, c: GgColors.sub), children: spans),
      textAlign: TextAlign.center,
    );

TextSpan _phone() => TextSpan(
    text: ggPhone,
    style: const TextStyle(color: GgColors.text, fontWeight: FontWeight.w800));

/// 화면 공통 틀: 머리말 + 단계 막대 + 말풍선 + 본문 + 아래 단추
class GgFrame extends StatelessWidget {
  final int step;
  final List<InlineSpan> bubble;
  final Widget body;
  final Widget bottom;
  final bool fill;
  const GgFrame(
      {Key? key,
      required this.step,
      required this.bubble,
      required this.body,
      required this.bottom,
      this.fill = true})
      : super(key: key);
  @override
  Widget build(BuildContext context) {
    final content = <Widget>[
      GgStepBar(step: step),
      const SizedBox(height: 16),
      GgBubble(spans: bubble),
      const SizedBox(height: 6),
      body,
      if (fill) const Spacer() else const SizedBox(height: 18),
      bottom,
    ];
    return Material(
      color: GgColors.bg,
      child: DefaultTextStyle(
        style: _t(14),
        child: Column(
          mainAxisSize: fill ? MainAxisSize.max : MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const GgHeader(),
            if (fill)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: content),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: content),
              ),
          ],
        ),
      ),
    );
  }
}

/// 1. 첫 화면: 접속번호·1회용 비밀번호
class GgHomePanel extends StatefulWidget {
  final TextEditingController id;
  final TextEditingController password;
  final VoidCallback onRefreshPassword;
  const GgHomePanel(
      {Key? key,
      required this.id,
      required this.password,
      required this.onRefreshPassword})
      : super(key: key);
  @override
  State<GgHomePanel> createState() => _GgHomePanelState();
}

class _GgHomePanelState extends State<GgHomePanel> {
  bool _told = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([widget.id, widget.password]),
      builder: (context, _) {
        final id = ggGroup3(widget.id.text);
        final pw = widget.password.text;
        final pwShown = pw.isEmpty || pw == '-' ? '-' : ggGroup3(pw);
        return GgFrame(
          fill: false,
          step: _told ? 2 : 1,
          bubble: _told
              ? [
                  const TextSpan(text: '기사님이 연결하면 '),
                  _b('허용 창'),
                  const TextSpan(text: '이 떠요. 기사님 이름을 보고 '),
                  _b('허용'),
                  const TextSpan(text: '을 눌러 주세요.'),
                ]
              : [
                  const TextSpan(text: '기사님께 아래 '),
                  _b('번호만'),
                  const TextSpan(text: ' 불러 주세요. 연결되면 제가 알려 드릴게요!'),
                ],
          body: GgCard(
            padding: const EdgeInsets.fromLTRB(16, 22, 16, 16),
            child: Column(children: [
              Text('접속번호', style: _t(12.5, c: GgColors.sub)),
              const SizedBox(height: 4),
              SelectableText(id.isEmpty ? '…' : id,
                  style: _t(52, w: FontWeight.w800, c: GgColors.accent)
                      .copyWith(
                          letterSpacing: 4,
                          height: 1.05,
                          fontFeatures: const [
                        FontFeature.tabularFigures()
                      ])),
              const SizedBox(height: 10),
              // 비밀번호는 기사님이 물을 때만 — 작은 상자로
              Container(
                padding: const EdgeInsets.fromLTRB(12, 2, 4, 2),
                decoration: BoxDecoration(
                  color: GgColors.bg,
                  border: Border.all(color: GgColors.line),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('기사님이 물으면 비밀번호 ',
                      style: _t(12.5, c: GgColors.sub)),
                  SelectableText(pwShown,
                      style: _t(13, w: FontWeight.w800)
                          .copyWith(letterSpacing: 3)),
                  Tooltip(
                    message: '비밀번호 새로 받기',
                    child: IconButton(
                      onPressed: widget.onRefreshPassword,
                      icon: const Icon(Icons.refresh, size: 15),
                      color: GgColors.sub,
                      splashRadius: 14,
                      constraints:
                          const BoxConstraints(minWidth: 30, minHeight: 30),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ]),
              ),
            ]),
          ),
          bottom: Column(children: [
            GgButton(
              label: _told ? '번호를 다시 볼게요' : '번호를 알려 드렸어요',
              onPressed: () => setState(() => _told = !_told),
            ),
            const SizedBox(height: 10),
            _footNote([const TextSpan(text: '전화가 안 되면 '), _phone()]),
          ]),
        );
      },
    );
  }
}

/// 첫 화면 아래 안내 카드(설치 안내 등) — 원래 분홍 그라데이션 카드 대신
class GgNoticeCard extends StatelessWidget {
  final String title;
  final String content;
  final String buttonText;
  final VoidCallback onPressed;
  const GgNoticeCard(
      {Key? key,
      required this.title,
      required this.content,
      required this.buttonText,
      required this.onPressed})
      : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 2, 18, 14),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: GgColors.card,
        border: Border.all(color: GgColors.line),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: GgColors.accent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.info_outline_rounded,
                  size: 17, color: GgColors.accent),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(title, style: _t(13.5, w: FontWeight.w800)),
                    ),
                  if (content.isNotEmpty)
                    Text(content,
                        style: _t(12.5, c: GgColors.sub).copyWith(height: 1.5)),
                ],
              ),
            ),
          ]),
          if (buttonText.isNotEmpty) ...[
            const SizedBox(height: 12),
            Material(
              color: Colors.transparent,
              shape: RoundedRectangleBorder(
                  side: const BorderSide(color: GgColors.accent),
                  borderRadius: BorderRadius.circular(12)),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onPressed,
                child: SizedBox(
                  height: 40,
                  child: Center(
                      child: Text(buttonText,
                          style: _t(14,
                              w: FontWeight.w800, c: GgColors.accent))),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 기사님용 접속 화면(기사님 exe = conn-type outgoing). 시안 B안 4.
/// 고객 번호(+선택 비밀번호)로 접속. 비밀번호를 비우면 고객 PC에 허용 창이 뜬다.
class GgTechPanel extends StatefulWidget {
  final Peers recent;
  final void Function(String id, String password) onConnect;
  const GgTechPanel({Key? key, required this.recent, required this.onConnect})
      : super(key: key);
  @override
  State<GgTechPanel> createState() => _GgTechPanelState();
}

class _GgTechPanelState extends State<GgTechPanel> {
  final _id = TextEditingController();
  final _pw = TextEditingController();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    widget.recent.addListener(_changed);
    bind.mainLoadRecentPeers();
    Future.delayed(const Duration(seconds: 2), _queryOnlines);
    _timer =
        Timer.periodic(const Duration(seconds: 20), (_) => _queryOnlines());
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  List<Peer> get _peers => widget.recent.peers.take(5).toList();

  void _queryOnlines() {
    if (!mounted) return;
    final ids = _peers.map((p) => p.id).toList();
    if (ids.isNotEmpty) bind.queryOnlines(ids: ids);
  }

  @override
  void dispose() {
    _timer?.cancel();
    widget.recent.removeListener(_changed);
    _id.dispose();
    _pw.dispose();
    super.dispose();
  }

  void _go(String id, String pw) {
    final clean = id.replaceAll(RegExp(r'\s'), '');
    if (clean.isEmpty) return;
    widget.onConnect(clean, pw.trim());
  }

  InputDecoration _deco(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: _t(15, c: const Color(0xFF5D6575)),
        filled: true,
        fillColor: GgColors.bg,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: GgColors.line)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: GgColors.accent)),
      );

  Widget _peerRow(Peer p) {
    final on = p.online;
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: GgColors.card,
        border: Border.all(color: GgColors.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: on ? GgColors.accent : const Color(0xFF4A5162),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Text(ggGroup3(p.id),
            style: _t(15, w: FontWeight.w800).copyWith(letterSpacing: 1)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(on ? '켜짐' : '꺼짐',
              overflow: TextOverflow.ellipsis,
              style: _t(12.5, c: GgColors.sub)),
        ),
        Material(
          color: Colors.transparent,
          shape: RoundedRectangleBorder(
              side: BorderSide(color: on ? GgColors.accent : GgColors.line),
              borderRadius: BorderRadius.circular(10)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _go(p.id, ''),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              child: Text('다시 접속',
                  style: _t(12.5,
                      w: FontWeight.w800,
                      c: on ? GgColors.accent : GgColors.sub)),
            ),
          ),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final peers = _peers;
    // 창 전체를 B안 바탕색으로(내용 아래 빈 곳이 회색으로 보이던 문제)
    return Material(
      color: GgColors.bg,
      child: DefaultTextStyle(
        style: _t(14),
        child: SizedBox.expand(
          child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                const Expanded(child: GgHeader()),
                Container(
                  margin: const EdgeInsets.only(right: 18, top: 6),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: GgColors.accent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('기사용',
                      style: _t(12, w: FontWeight.w800, c: GgColors.accent)),
                ),
              ]),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 6, 18, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    GgCard(
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('고객 접속번호',
                              style: _t(12.5, c: GgColors.sub)),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _id,
                            autofocus: true,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            cursorColor: GgColors.accent,
                            style: _t(32, w: FontWeight.w800, c: GgColors.accent)
                                .copyWith(letterSpacing: 4, height: 1.1),
                            decoration: _deco('000 000'),
                            onSubmitted: (_) => _go(_id.text, _pw.text),
                          ),
                          const SizedBox(height: 12),
                          Text.rich(TextSpan(
                              style: _t(12.5, c: GgColors.sub),
                              children: const [
                                TextSpan(text: '비밀번호 '),
                                TextSpan(
                                    text: '(비워 두면 고객이 "허용"을 눌러요)',
                                    style: TextStyle(color: Color(0xFF7D8697))),
                              ])),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _pw,
                            keyboardType: TextInputType.number,
                            cursorColor: GgColors.accent,
                            style: _t(16, w: FontWeight.w700)
                                .copyWith(letterSpacing: 2),
                            decoration: _deco('선택'),
                            onSubmitted: (_) => _go(_id.text, _pw.text),
                          ),
                          const SizedBox(height: 14),
                          GgButton(
                              label: '접속하기',
                              onPressed: () => _go(_id.text, _pw.text)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('최근 접속한 고객 PC',
                        style: _t(12.5, w: FontWeight.w700, c: GgColors.sub)),
                    if (peers.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text('아직 없어요',
                            style: _t(12.5, c: const Color(0xFF7D8697))),
                      ),
                    ...peers.map(_peerRow),
                    const SizedBox(height: 18),
                    Text.rich(
                      TextSpan(
                          style: _t(12.5, c: GgColors.sub),
                          children: const [
                            TextSpan(text: '고객 화면에는 '),
                            TextSpan(
                                text: '궁구미 기사님',
                                style: TextStyle(
                                    color: GgColors.text,
                                    fontWeight: FontWeight.w800)),
                            TextSpan(text: '으로 보여요'),
                          ]),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }
}

/// 첫 화면 아래 "프로그램 끄기"(원래 받기 전용 "종료" 단추)
class GgQuitButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  const GgQuitButton({Key? key, required this.label, required this.onPressed})
      : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
      child: Material(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(
            side: const BorderSide(color: GgColors.line),
            borderRadius: BorderRadius.circular(12)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            height: 40,
            width: double.infinity,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.power_settings_new_rounded,
                    size: 16, color: GgColors.sub),
                const SizedBox(width: 6),
                Text(label, style: _t(13.5, w: FontWeight.w700, c: GgColors.sub)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 2. 연결 허용 화면(기사님이 비밀번호 없이 연결을 요청했을 때)
/// showAccept=false(비밀번호로만 받는 설정)면 허용 단추 없이 거절만 보여 줌
class GgApproveView extends StatelessWidget {
  final String peerName;
  final String peerId;
  final bool canInput;
  final bool canFile;
  final bool canClipboard;
  final bool showAccept;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  const GgApproveView(
      {Key? key,
      required this.peerName,
      required this.peerId,
      required this.canInput,
      required this.canFile,
      required this.canClipboard,
      required this.showAccept,
      required this.onAccept,
      required this.onReject})
      : super(key: key);

  Widget _can(IconData icon, String label) => Padding(
        padding: const EdgeInsets.only(top: 9),
        child: Row(children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: GgColors.bg,
              border: Border.all(color: GgColors.line),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 15, color: GgColors.sub),
          ),
          const SizedBox(width: 10),
          Text(label, style: _t(13.5, c: const Color(0xFFC9CFDA))),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final name = peerName.trim().isEmpty ? '기사님' : peerName.trim();
    return GgFrame(
      step: 2,
      bubble: showAccept
          ? [
              const TextSpan(text: '기사님이 '),
              _b('연결을 요청'),
              const TextSpan(text: '했어요. 궁구미 기사님이 맞으면 '),
              _b('허용'),
              const TextSpan(text: '을 눌러 주세요.'),
            ]
          : [
              const TextSpan(text: '기사님이 '),
              _b('비밀번호'),
              const TextSpan(text: '를 넣는 중이에요. 잠시만 기다려 주세요.'),
            ],
      body: GgCard(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('연결을 요청한 사람', style: _t(12.5, c: GgColors.sub)),
            const SizedBox(height: 4),
            Row(children: [
              Expanded(
                child: Text(name,
                    overflow: TextOverflow.ellipsis,
                    style: _t(18, w: FontWeight.w800)),
              ),
              if (peerId.isNotEmpty)
                Text(ggGroup3(peerId), style: _t(13, c: GgColors.sub)),
            ]),
            const SizedBox(height: 12),
            const Divider(height: 1, color: GgColors.line),
            const SizedBox(height: 10),
            Text('허용하면 기사님이 할 수 있는 일', style: _t(12.5, c: GgColors.sub)),
            _can(Icons.visibility_outlined, '화면 보기'),
            if (canInput) _can(Icons.mouse_outlined, '마우스·키보드 사용'),
            if (canFile) _can(Icons.folder_outlined, '파일 주고받기'),
            if (canClipboard) _can(Icons.content_paste, '복사·붙여넣기'),
          ],
        ),
      ),
      bottom: Column(children: [
        if (showAccept) ...[
          GgButton(label: '허용', onPressed: onAccept),
          const SizedBox(height: 10),
        ],
        // CM 창 테마가 OutlinedButton 바탕을 흰색으로 덮어써서(run 45298497880) 직접 그림
        Material(
          color: GgColors.card,
          shape: RoundedRectangleBorder(
              side: const BorderSide(color: GgColors.line),
              borderRadius: BorderRadius.circular(14)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onReject,
            child: SizedBox(
              height: 46,
              width: double.infinity,
              child: Center(
                  child: Text('거절', style: _t(15, w: FontWeight.w700))),
            ),
          ),
        ),
        const SizedBox(height: 10),
        _footNote([const TextSpan(text: '모르는 사람이면 거절하고 '), _phone()]),
      ]),
    );
  }
}

/// 3. 연결 중 화면
class GgConnectedView extends StatefulWidget {
  final String peerName;
  final bool canInput;
  final bool canFile;
  final bool canClipboard;
  final VoidCallback onEnd;
  const GgConnectedView(
      {Key? key,
      required this.peerName,
      required this.canInput,
      required this.canFile,
      required this.canClipboard,
      required this.onEnd})
      : super(key: key);
  @override
  State<GgConnectedView> createState() => _GgConnectedViewState();
}

class _GgConnectedViewState extends State<GgConnectedView> {
  Timer? _timer;
  late final DateTime _start;

  @override
  void initState() {
    super.initState();
    GgSession.started();
    _start = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          GgSession.lastSeconds = DateTime.now().difference(_start).inSeconds;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Widget _can(IconData icon, String label) => Padding(
        padding: const EdgeInsets.only(top: 9),
        child: Row(children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: GgColors.bg,
              border: Border.all(color: GgColors.line),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 15, color: GgColors.sub),
          ),
          const SizedBox(width: 10),
          Text(label, style: _t(13.5, c: const Color(0xFFC9CFDA))),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final name = widget.peerName.trim().isEmpty ? '궁구미 기사님' : widget.peerName;
    return GgFrame(
      step: 3,
      bubble: [
        const TextSpan(text: '기사님이 지금 '),
        _b('PC를 보고 있어요.'),
        const TextSpan(text: ' 마우스가 혼자 움직여도 놀라지 마세요!'),
      ],
      body: GgCard(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: GgColors.accent,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: GgColors.accent.withOpacity(0.2),
                        spreadRadius: 4)
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text('연결됨 · $name',
                    overflow: TextOverflow.ellipsis,
                    style: _t(14, w: FontWeight.w800)),
              ),
              Text(ggDuration(GgSession.lastSeconds),
                  style: _t(20, w: FontWeight.w800).copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()])),
            ]),
            const SizedBox(height: 12),
            const Divider(height: 1, color: GgColors.line),
            const SizedBox(height: 3),
            _can(Icons.visibility_outlined, '화면 보기'),
            if (widget.canInput) _can(Icons.mouse_outlined, '마우스·키보드 사용'),
            if (widget.canFile) _can(Icons.folder_outlined, '파일 주고받기'),
            if (widget.canClipboard) _can(Icons.content_paste, '복사·붙여넣기'),
          ],
        ),
      ),
      bottom: Column(children: [
        GgButton(
            label: '원격 끝내기',
            color: GgColors.danger,
            onPressed: () {
              GgSession.ended();
              widget.onEnd();
            }),
        const SizedBox(height: 10),
        _footNote([const TextSpan(text: '누르면 바로 연결이 끊겨요. 언제든 괜찮아요.')]),
      ]),
    );
  }
}

/// 4. 끝난 화면
class GgEndedView extends StatelessWidget {
  final int seconds;
  final VoidCallback onClose;
  const GgEndedView({Key? key, required this.seconds, required this.onClose})
      : super(key: key);
  @override
  Widget build(BuildContext context) {
    final minutes = (seconds / 60).ceil();
    return GgFrame(
      step: 4,
      bubble: [
        const TextSpan(text: '원격이 '),
        _b('끝났어요.'),
        const TextSpan(text: ' 이제 기사님은 이 PC를 볼 수 없어요.'),
      ],
      body: GgCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(children: [
          SvgPicture.string(_checkSvg, width: 44, height: 44),
          const SizedBox(height: 8),
          Text('연결이 안전하게 끊겼어요', style: _t(18, w: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(seconds < 60 ? '원격 시간 1분 미만' : '원격 시간 $minutes분',
              style: _t(13, c: GgColors.sub)),
        ]),
      ),
      bottom: Column(children: [
        GgButton(label: '닫기', onPressed: onClose),
        const SizedBox(height: 10),
        _footNote([const TextSpan(text: '아직 불편하면 '), _phone()]),
      ]),
    );
  }
}
