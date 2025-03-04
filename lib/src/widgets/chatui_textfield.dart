/*
 * Copyright (c) 2022 Simform Solutions
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */
import 'dart:async';
import 'dart:io' show Platform;

import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:chatview/src/utils/constants/constants.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../chatview.dart';
import '../utils/debounce.dart';
import '../utils/package_strings.dart';

class ChatUITextField extends StatefulWidget {
  const ChatUITextField({
    Key? key,
    this.sendMessageConfig,
    required this.focusNode,
    required this.textEditingController,
    required this.onPressed,
    required this.onRecordingComplete,
    required this.onImageSelected,
    this.onClosePressed,
  }) : super(key: key);

  /// Provides configuration of default text field in chat.
  final SendMessageConfiguration? sendMessageConfig;

  /// Provides focusNode for focusing text field.
  final FocusNode focusNode;

  /// Provides functions which handles text field.
  final TextEditingController textEditingController;

  /// Provides callback when user tap on text field.
  final VoidCallBack onPressed;

  /// Provides callback when user tap on close button.
  final VoidCallBack? onClosePressed;

  /// Provides callback once voice is recorded.
  final Function(String?) onRecordingComplete;

  /// Provides callback when user select images from camera/gallery.
  final StringsCallBack onImageSelected;

  @override
  State<ChatUITextField> createState() => _ChatUITextFieldState();
}

class _ChatUITextFieldState extends State<ChatUITextField> {
  final ValueNotifier<String> _inputText = ValueNotifier('');

  final ImagePicker _imagePicker = ImagePicker();

  RecorderController? controller;

  ValueNotifier<bool> isRecording = ValueNotifier(false);

  SendMessageConfiguration? get sendMessageConfig => widget.sendMessageConfig;

  VoiceRecordingConfiguration? get voiceRecordingConfig => widget.sendMessageConfig?.voiceRecordingConfiguration;

  ImagePickerIconsConfiguration? get imagePickerIconsConfig => sendMessageConfig?.imagePickerIconsConfig;

  TextFieldConfiguration? get textFieldConfig => sendMessageConfig?.textFieldConfig;

  OutlineInputBorder get _outLineBorder => OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.transparent),
        borderRadius: textFieldConfig?.borderRadius ?? BorderRadius.circular(textFieldBorderRadius),
      );

  ValueNotifier<TypeWriterStatus> composingStatus = ValueNotifier(TypeWriterStatus.typed);

  late Debouncer debouncer;

  @override
  void initState() {
    attachListeners();
    debouncer = Debouncer(sendMessageConfig?.textFieldConfig?.compositionThresholdTime ?? const Duration(seconds: 1));
    super.initState();

    if (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android) {
      controller = RecorderController();
    }
  }

  @override
  void dispose() {
    debouncer.dispose();
    composingStatus.dispose();
    isRecording.dispose();
    _inputText.dispose();
    super.dispose();
  }

  void attachListeners() {
    composingStatus.addListener(() {
      widget.sendMessageConfig?.textFieldConfig?.onMessageTyping?.call(composingStatus.value);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: textFieldConfig?.padding ?? const EdgeInsets.symmetric(horizontal: 6),
      margin: textFieldConfig?.margin,
      decoration: BoxDecoration(
        borderRadius: textFieldConfig?.borderRadius ?? BorderRadius.circular(textFieldBorderRadius),
        color: sendMessageConfig?.textFieldBackgroundColor ?? Colors.white,
      ),
      child: ValueListenableBuilder<bool>(
        valueListenable: isRecording,
        builder: (_, isRecordingValue, child) {
          return Row(
            children: [
              if (isRecordingValue && controller != null && !kIsWeb)
                AudioWaveforms(
                  size: Size(MediaQuery.of(context).size.width * 0.75, 50),
                  recorderController: controller!,
                  margin: voiceRecordingConfig?.margin,
                  padding: voiceRecordingConfig?.padding ?? const EdgeInsets.symmetric(horizontal: 8),
                  decoration: voiceRecordingConfig?.decoration ??
                      BoxDecoration(
                        color: voiceRecordingConfig?.backgroundColor,
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                  waveStyle: voiceRecordingConfig?.waveStyle ??
                      WaveStyle(
                        extendWaveform: true,
                        showMiddleLine: false,
                        waveColor: voiceRecordingConfig?.waveStyle?.waveColor ?? Colors.black,
                      ),
                )
              else if (sendMessageConfig?.showCloseButtonIcon ?? false)
                GestureDetector(
                  onTap: () {
                    FocusManager.instance.primaryFocus?.unfocus();
                    widget.onClosePressed?.call();
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: sendMessageConfig?.closeButtonIcon ??
                        Icon(
                          Icons.close,
                          color: imagePickerIconsConfig?.cameraIconColor,
                        ),
                  ),
                ),
              Expanded(
                child: TextField(
                  focusNode: widget.focusNode,
                  controller: widget.textEditingController,
                  style: textFieldConfig?.textStyle ?? const TextStyle(color: Colors.white),
                  maxLines: textFieldConfig?.maxLines ?? 5,
                  minLines: textFieldConfig?.minLines ?? 1,
                  keyboardType: textFieldConfig?.textInputType,
                  textInputAction: textFieldConfig?.textInputAction,
                  inputFormatters: textFieldConfig?.inputFormatters,
                  onChanged: _onChanged,
                  onSubmitted: (text) {
                    if (text.isNotEmpty) {
                      _onChanged(text);
                      widget.onPressed();
                    }
                    textFieldConfig?.onSubmitMessage?.call(text);
                  },
                  textCapitalization: textFieldConfig?.textCapitalization ?? TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: textFieldConfig?.hintText ?? PackageStrings.message,
                    fillColor: sendMessageConfig?.textFieldBackgroundColor ?? Colors.white,
                    filled: true,
                    hintStyle: textFieldConfig?.hintStyle ??
                        TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                          color: Colors.grey.shade600,
                          letterSpacing: 0.25,
                        ),
                    contentPadding: textFieldConfig?.contentPadding ?? const EdgeInsets.symmetric(horizontal: 6),
                    border: _outLineBorder,
                    focusedBorder: _outLineBorder,
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.transparent),
                      borderRadius: textFieldConfig?.borderRadius ?? BorderRadius.circular(textFieldBorderRadius),
                    ),
                  ),
                ),
              ),
              ValueListenableBuilder<String>(
                valueListenable: _inputText,
                builder: (_, inputTextValue, child) {
                  if (inputTextValue.isNotEmpty) {
                    return GestureDetector(
                      onTap: () {
                        widget.onPressed();
                        _inputText.value = '';
                      },
                      child: sendMessageConfig?.sendButtonIcon ??
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Icon(
                              Icons.send,
                              color: sendMessageConfig?.defaultSendButtonColor ?? Colors.green,
                            ),
                          ),
                    );
                  } else {
                    return Row(
                      children: [
                        if (!isRecordingValue) ...[
                          if (sendMessageConfig?.enableCameraImagePicker ?? true)
                            IconButton(
                              constraints: const BoxConstraints(),
                              onPressed: () => _onIconPressed(
                                ImageSource.camera,
                                config: sendMessageConfig?.imagePickerConfiguration,
                              ),
                              icon: imagePickerIconsConfig?.cameraImagePickerIcon ??
                                  Icon(
                                    Icons.camera_alt_outlined,
                                    color: imagePickerIconsConfig?.cameraIconColor,
                                  ),
                            ),
                          if (sendMessageConfig?.enableGalleryImagePicker ?? true)
                            IconButton(
                              constraints: const BoxConstraints(),
                              onPressed: () => _onIconPressed(
                                ImageSource.gallery,
                                config: sendMessageConfig?.imagePickerConfiguration,
                              ),
                              icon: imagePickerIconsConfig?.galleryImagePickerIcon ??
                                  Icon(
                                    Icons.image,
                                    color: imagePickerIconsConfig?.galleryIconColor,
                                  ),
                            ),
                        ],
                        if (sendMessageConfig?.allowRecordingVoice ??
                            true && Platform.isIOS && Platform.isAndroid && !kIsWeb)
                          IconButton(
                            onPressed: _recordOrStop,
                            icon: (isRecordingValue ? voiceRecordingConfig?.micIcon : voiceRecordingConfig?.stopIcon) ??
                                Icon(isRecordingValue ? Icons.stop : Icons.mic),
                            color: voiceRecordingConfig?.recorderIconColor,
                          )
                      ],
                    );
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _recordOrStop() async {
    assert(
      defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android,
      "Voice messages are only supported with android and ios platform",
    );
    if (!isRecording.value) {
      final tempDir = await getTemporaryDirectory();
      await controller?.record(path: '${tempDir.path}/voice_message_${DateTime.now().millisecondsSinceEpoch}.m4a');
      isRecording.value = true;
    } else {
      final path = await controller?.stop();
      isRecording.value = false;
      widget.onRecordingComplete(path);
    }
  }

  void _onIconPressed(
    ImageSource imageSource, {
    ImagePickerConfiguration? config,
  }) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: imageSource,
        maxHeight: config?.maxHeight,
        maxWidth: config?.maxWidth,
        imageQuality: config?.imageQuality,
        preferredCameraDevice: config?.preferredCameraDevice ?? CameraDevice.rear,
      );
      String? imagePath = image?.path;
      if (config?.onImagePicked != null) {
        String? updatedImagePath = await config?.onImagePicked!(imagePath);
        if (updatedImagePath != null) imagePath = updatedImagePath;
      }
      widget.onImageSelected(imagePath ?? '', '');
    } catch (e) {
      widget.onImageSelected('', e.toString());
    }
  }

  void _onChanged(String inputText) {
    debouncer.run(() {
      composingStatus.value = TypeWriterStatus.typed;
    }, () {
      composingStatus.value = TypeWriterStatus.typing;
    });
    _inputText.value = inputText;
  }
}
