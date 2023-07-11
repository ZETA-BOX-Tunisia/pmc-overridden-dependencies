// Copyright 2020 the Dart project authors.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file or at
// https://developers.google.com/open-source/licenses/bsd

import 'package:flutter/material.dart';

import 'builder.dart';
import 'primitives/tree_controller.dart';
import 'primitives/tree_node.dart';

/// Widget that displays one [TreeNode] and its children.
class NodeWidget extends StatefulWidget {
  final TreeNode treeNode;
  final double? indent;
  final double? iconSize;
  final TreeController state;
  final Function? function;

  const NodeWidget(
      {Key? key,
      required this.treeNode,
      this.indent,
      this.function,
      required this.state,
      this.iconSize})
      : super(key: key);

  @override
  _NodeWidgetState createState() => _NodeWidgetState();
}

class _NodeWidgetState extends State<NodeWidget> {
  bool get _isLeaf {
    return widget.treeNode.children == null ||
        widget.treeNode.children!.isEmpty;
  }
  bool get _isExpanded {
    return widget.state.isNodeExpanded(widget.treeNode.key!);
  }

  @override
  void initState() {
    super.initState();

  }



  @override
  Widget build(BuildContext context) {
    var icon = _isLeaf
        ? null
        : _isExpanded
            ? Icons.expand_more
            : Icons.chevron_right;

    var onIconPressed = _isLeaf
        ? null
        : () => setState(
            () => widget.state.toggleNodeExpanded(widget.treeNode.key!));


    return Container(
      margin: EdgeInsets.only(bottom: 0),
      child:  SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: /*widget.treeNode.height!,*/130 * (widget.treeNode.children!.length + 1) *1.0,
              width: MediaQuery.of(context).size.width * .6,
              child: Stack(
              children: [
                widget.treeNode.content,
                  Positioned(
                    left:35,
                    top: 75,
                    child: Container(
                      height: 40,
                      width: .6,
                      decoration: BoxDecoration(
                        color: const Color(0xffD9D9D9),
                        borderRadius: BorderRadius.circular(9),
                      ),
                    ),),
                  Positioned(
                    top: 105,
                    left:33,
                    child: Row(
                      children: [
                        Container(
                          height: 1,
                          width: 62,
                          margin: const EdgeInsets.only(top: 0),
                          decoration: BoxDecoration(
                            color: const Color(0xffD9D9D9),
                            borderRadius: BorderRadius.circular(9),
                          ),
                        ),
                        InkWell(
                          onTap: () {
                            widget.treeNode!.function!.call();
                          },
                          child: CircleAvatar(
                            backgroundColor: Color(0xff045692),
                            radius: 8,
                            child: Center(
                              child: Icon(
                                Icons.add,
                                color: Colors.white,
                                size: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if(widget.treeNode.children!.isNotEmpty) Positioned(
                            top: 105,
                            left:33,
                            child: Row(
                              children: [
                                InkWell(
                                  onTap: () {
                                    widget.treeNode!.function!.call();

                                  },
                                  child: CircleAvatar(
                                    backgroundColor: Color(0xff045692),
                                    radius: 8,
                                    child: Center(
                                      child: Icon(
                                        Icons.add,
                                        color: Colors.white,
                                        size: 14,
                                      ),
                                    ),
                                  ),
                                ),
                                Container(
                                  height: 1,
                                  width: 72,
                                  margin: const EdgeInsets.only(top: 0),
                                  decoration: BoxDecoration(
                                    color: const Color(0xffD9D9D9),
                                    borderRadius: BorderRadius.circular(9),
                                  ),
                                ),

                              ],
                            ),
      ),
                Positioned(
                    top:60,
                    left: 40,
                    child: Padding(
                      padding: EdgeInsets.only(left: widget.indent!),
                      child: Stack(
                        children: [
                          if(widget.treeNode.children!.isNotEmpty )...[
                            Positioned(
                              left:35,
                              top: 65,
                              child: Container(
                                height: 40,
                                width: .6,
                                decoration: BoxDecoration(
                                  color: const Color(0xffD9D9D9),
                                  borderRadius: BorderRadius.circular(9),
                                ),
                              ),),
                            Positioned(
                              top: 105,
                              left:35,
                              child: Row(
                                children: [
                                  Container(
                                    height: 1,
                                    width: 60,
                                    margin: const EdgeInsets.only(top: 0),
                                    decoration: BoxDecoration(
                                      color: const Color(0xffD9D9D9),
                                      borderRadius: BorderRadius.circular(9),
                                    ),
                                  ),
                                  InkWell(
                                    onTap: () {
                                      widget.treeNode!.function!.call();
                                    },
                                    child: CircleAvatar(
                                      backgroundColor: Color(0xff045692),
                                      radius: 8,
                                      child: Center(
                                        child: Icon(
                                          Icons.add,
                                          color: Colors.white,
                                          size: 14,
                                        ),
                                      ),
                                    ),
                                  ),

                                ],
                              ),
                            ),

                          ],
                          buildNodes(widget.treeNode.children!, widget.indent! , widget.state, widget.iconSize,widget.function!),

                        ],
                      ),
                    ))
              ],

            ),)


          ],
        ),
      ),
    );
  }
}
