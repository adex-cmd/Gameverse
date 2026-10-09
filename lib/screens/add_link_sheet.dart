import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../actions.dart';
import '../app_scope.dart';
import '../models/movie.dart';
import '../services/commons_api.dart';
import '../theme.dart';
import '../utils/responsive.dart';
import '../widgets/common.dart';

Future<void> showAddLinkSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _AddLinkSheet(parentContext: context),
  );
}

class _AddLinkSheet extends StatefulWidget {
  const _AddLinkSheet({required this.parentContext});

  /// Stays mounted after the sheet closes, for navigation and snackbars.
  final BuildContext parentContext;

  @override
  State<_AddLinkSheet> createState() => _AddLinkSheetState();
}

class _AddLinkSheetState extends State<_AddLinkSheet> {
  final _controller = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) return;
    _controller.text = text;
    setState(() => _error = null);
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    final uri = Uri.tryParse(text);
    if (uri == null ||
        !(uri.scheme == 'http' || uri.scheme == 'https') ||
        uri.host.isEmpty) {
      setState(
        () => _error = 'Enter a full link starting with http:// or https://',
      );
      return;
    }

    final parent = widget.parentContext;
    final navigator = Navigator.of(context);

    // A film page on a supported site: open it in the app to pick a quality.
    final segments = uri.pathSegments;
    Movie? page;
    if (uri.host.endsWith('archive.org') &&
        segments.length >= 2 &&
        segments[0] == 'details') {
      page = Movie(id: segments[1], title: segments[1]);
    } else if (uri.host.endsWith('commons.wikimedia.org') &&
        segments.length >= 2 &&
        segments[0] == 'wiki' &&
        segments[1].startsWith('File:')) {
      final id = segments[1].replaceAll('_', ' ');
      page = Movie(
        id: id,
        title: parseCommonsTitle(id).title,
        source: MovieSource.commons,
      );
    }
    if (page != null) {
      navigator.pop();
      if (parent.mounted) openMovie(parent, page);
      return;
    }

    final scope = AppScope.of(context);
    final messenger = ScaffoldMessenger.of(parent);
    setState(() => _busy = true);
    try {
      await scope.downloads.add(text);
    } catch (e) {
      setState(() {
        _busy = false;
        _error = 'Couldn\'t start the download: $e';
      });
      return;
    }
    navigator.pop();
    scope.tab.value = 1;
    messenger.showSnackBar(const SnackBar(content: Text('Download started')));
  }

  @override
  Widget build(BuildContext context) {
    // Lifts the sheet above the keyboard; it scrolls if the screen is short.
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final gutter = context.gutter + 4;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 24 + keyboard),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('DOWNLOAD FROM A LINK', style: displayStyle(context.rs(30))),
          const SizedBox(height: 6),
          const Text(
            'Paste a direct link to a video file, or a film page from archive.org or Wikimedia Commons.',
            style: TextStyle(color: AppColors.textDim, height: 1.4),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.url,
            autocorrect: false,
            textInputAction: TextInputAction.go,
            onSubmitted: (_) => _submit(),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            decoration: InputDecoration(
              hintText: 'https://…',
              errorText: _error,
              errorMaxLines: 3,
              prefixIcon: const Icon(
                Icons.link_rounded,
                color: AppColors.textDim,
              ),
              suffixIcon: IconButton(
                tooltip: 'Paste',
                icon: const Icon(
                  Icons.content_paste_rounded,
                  color: AppColors.textDim,
                ),
                onPressed: _paste,
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: GradientButton(
              label: _busy ? 'Starting…' : 'Start download',
              icon: Icons.download_rounded,
              expand: true,
              onPressed: _busy ? null : _submit,
            ),
          ),
          const SizedBox(height: 14),
          const Center(
            child: Text(
              'Only download content you have the right to.',
              style: TextStyle(color: AppColors.textDim, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
