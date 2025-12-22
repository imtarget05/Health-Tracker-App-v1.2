import 'dart:developer';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:best_flutter_ui_templates/fitness_app/notification/Chatbox/providers/chat_provider.dart';
import 'package:best_flutter_ui_templates/fitness_app/notification/Chatbox/utility/animated_dialog.dart';
import 'package:best_flutter_ui_templates/fitness_app/notification/Chatbox/widgets/preview_images_widget.dart';
import 'package:image_picker/image_picker.dart';

class BottomChatField extends StatefulWidget {
  const BottomChatField({
    super.key,
    required this.chatProvider,
  });

  final ChatProvider chatProvider;

  @override
  State<BottomChatField> createState() => _BottomChatFieldState();
}

class _BottomChatFieldState extends State<BottomChatField> {
  // controller for the input field
  final TextEditingController textController = TextEditingController();

  // focus node for the input field
  final FocusNode textFieldFocus = FocusNode();

  // initialize image picker
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    textController.dispose();
    textFieldFocus.dispose();
    super.dispose();
  }

  Future<void> sendChatMessage({
    required String message,
    required ChatProvider chatProvider,
    required bool isTextOnly,
  }) async {
    try {
      // Ensure any composing text from IME is committed by removing focus
      // then read the controller value after a short delay.
      textFieldFocus.unfocus();
      await Future.delayed(const Duration(milliseconds: 80));
      final toSend = textController.text.isNotEmpty ? textController.text : message;

      await chatProvider.sentMessage(
        message: toSend,
        isTextOnly: isTextOnly,
      );
    } catch (e) {
      log('error : $e');
    } finally {
      // Clear input and update UI without clobbering IME composing state.
      // Use clear() and set a collapsed selection instead of resetting the
      // entire TextEditingValue which can interrupt some Vietnamese IMEs.
      setState(() {
        textController.clear();
        textController.selection = const TextSelection.collapsed(offset: 0);
      });
      widget.chatProvider.setImagesFileList(listValue: []);
      // remove focus from text field
      textFieldFocus.unfocus();
      // Hide the platform keyboard to ensure IME state is reset on some platforms
      // (best-effort; ignore failures).
      try {
        SystemChannels.textInput.invokeMethod('TextInput.hide');
      } catch (_) {}
    }
  }

  // pick an image
  void pickImage() async {
    try {
      final pickedImages = await _picker.pickMultiImage(
        maxHeight: 800,
        maxWidth: 800,
        imageQuality: 95,
      );
      widget.chatProvider.setImagesFileList(listValue: pickedImages);
    } catch (e) {
      log('error : $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    bool hasImages = widget.chatProvider.imagesFileList != null &&
        widget.chatProvider.imagesFileList!.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: Theme.of(context).textTheme.titleLarge!.color!,
        ),
      ),
      child: Column(
        children: [
          if (hasImages) const PreviewImagesWidget(),
          Row(
            children: [
              IconButton(
                onPressed: () {
                  if (hasImages) {
                    // show the delete dialog
            showMyAnimatedDialog(
              context: context,
              title: 'Xoá hình',
              content: 'Bạn có chắc muốn xoá các hình này?',
              actionText: 'Xoá',
                        onActionPressed: (value) {
                          if (value) {
                            widget.chatProvider.setImagesFileList(
                              listValue: [],
                            );
                          }
                        });
                  } else {
                    pickImage();
                  }
                },
                icon: Icon(
                  hasImages ? CupertinoIcons.delete : CupertinoIcons.photo,
                ),
              ),
              const SizedBox(
                width: 5,
              ),
              Expanded(
                child: TextField(
                  focusNode: textFieldFocus,
                  controller: textController,
                  onChanged: (v) {
                    // ensure UI reflects current text during IME composition
                    setState(() {});
                  },
                  textInputAction: TextInputAction.send,
                  onSubmitted: widget.chatProvider.isLoading
                      ? null
                      : (String value) {
                          if (value.isNotEmpty) {
                            // send the message
                            sendChatMessage(
                              message: textController.text,
                              chatProvider: widget.chatProvider,
                              isTextOnly: hasImages ? false : true,
                            );
                          }
                        },
          decoration: InputDecoration.collapsed(
            hintText: 'Nhập nội dung...',
                      border: OutlineInputBorder(
                        borderSide: BorderSide.none,
                        borderRadius: BorderRadius.circular(30),
                      )),
                ),
              ),
              GestureDetector(
                onTap: widget.chatProvider.isLoading
                    ? null
                    : () {
                        if (textController.text.isNotEmpty) {
                          // send the message
                          sendChatMessage(
                            message: textController.text,
                            chatProvider: widget.chatProvider,
                            isTextOnly: hasImages ? false : true,
                          );
                        }
                      },
                child: Container(
                    decoration: BoxDecoration(
                      color: Colors.deepPurple,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    margin: const EdgeInsets.all(5.0),
                    child: const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Icon(
                        // Icons.arrow_upward,
                        CupertinoIcons.arrow_up,
                        color: Colors.white,
                      ),
                    )),
              )
            ],
          ),
        ],
      ),
    );
  }
}
