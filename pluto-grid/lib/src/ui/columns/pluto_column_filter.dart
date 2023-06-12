import 'dart:async';
import 'dart:convert';

import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:pluto_grid/pluto_grid.dart';

import '../ui.dart';

class PlutoColumnFilter extends PlutoStatefulWidget {
  final PlutoGridStateManager stateManager;
  final PlutoColumn column;
  final bool disableFilter;

  PlutoColumnFilter({
    required this.stateManager,
    required this.column,
    this.disableFilter = false,
    Key? key,
  }) : super(key: ValueKey('column_filter_${column.key}'));

  @override
  PlutoColumnFilterState createState() => PlutoColumnFilterState();
}

class PlutoColumnFilterState extends PlutoStateWithChange<PlutoColumnFilter> {
  List<PlutoRow> _filterRows = [];
  String _selectedFilter = '';
  String _text = '';
  bool _enabled = false;
  bool isfilterMenuOpen = false;
  late final StreamSubscription _event;
  late final FocusNode _focusNode;
  late final TextEditingController _controller;

  String get _filterValue {
    return _filterRows.isEmpty ? '' : _filterRows.first.cells[FilterHelper.filterFieldValue]!.value.toString();
  }

  bool get _hasCompositeFilter {
    return _filterRows.length > 1 || stateManager.filterRowsByField(FilterHelper.filterFieldAllColumns).isNotEmpty;
  }

  InputBorder get _border => OutlineInputBorder(
        borderSide: BorderSide(color: Colors.transparent, width: 0.0),
        borderRadius: BorderRadius.zero,
      );

  InputBorder get _enabledBorder => OutlineInputBorder(
        borderSide: BorderSide(color: Colors.transparent, width: 0.0),
        borderRadius: BorderRadius.zero,
      );

  InputBorder get _disabledBorder => OutlineInputBorder(
        borderSide: BorderSide(color: Colors.transparent, width: 0.0),
        borderRadius: BorderRadius.zero,
      );

  InputBorder get _focusedBorder => OutlineInputBorder(
        borderSide: BorderSide(color: Colors.transparent, width: 0.0),
        borderRadius: BorderRadius.zero,
      );

  Color get _textFieldColor => _enabled ? stateManager.configuration.style.cellColorInEditState : stateManager.configuration.style.cellColorInReadOnlyState;

  EdgeInsets get _padding => widget.column.filterPadding ?? stateManager.configuration.style.defaultColumnFilterPadding;

  Color get _colorFilter => widget.column.colorFilter ?? Color(0xFFF8F8F8);

  bool? get _disabledFilter => widget.column.disabledFilter;

  @override
  PlutoGridStateManager get stateManager => widget.stateManager;

  @override
  initState() {
    super.initState();
    _focusNode = FocusNode(onKey: _handleOnKey);
    widget.column.setFilterFocusNode(_focusNode);
    _controller = TextEditingController(text: _filterValue);
    _event = stateManager.eventManager!.listener(_handleFocusFromRows);
    updateState(PlutoNotifierEventForceUpdate.instance);
  }

  @override
  dispose() {
    _event.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void updateState(PlutoNotifierEvent event) {
    _filterRows = update<List<PlutoRow>>(
      _filterRows,
      stateManager.filterRowsByField(widget.column.field),
      compare: listEquals,
    );
    if (_focusNode.hasPrimaryFocus != true) {
      _text = update<String>(_text, _filterValue);
      if (changed) {
        _controller.text = _text;
      }
    }
    _enabled = update<bool>(
      _enabled,
      widget.column.enableFilterMenuItem && !_hasCompositeFilter,
    );
  }

  void _moveDown({required bool focusToPreviousCell}) {
    if (!focusToPreviousCell || stateManager.currentCell == null) {
      stateManager.setCurrentCell(
        stateManager.refRows.first.cells[widget.column.field],
        0,
        notify: false,
      );
      stateManager.scrollByDirection(PlutoMoveDirection.down, 0);
    }
    stateManager.setKeepFocus(true, notify: false);
    stateManager.gridFocusNode.requestFocus();
    stateManager.notifyListeners();
  }

  KeyEventResult _handleOnKey(FocusNode node, RawKeyEvent event) {
    var keyManager = PlutoKeyManagerEvent(
      focusNode: node,
      event: event,
    );
    if (keyManager.isKeyUpEvent) {
      return KeyEventResult.handled;
    }
    final handleMoveDown = (keyManager.isDown || keyManager.isEnter || keyManager.isEsc) && stateManager.refRows.isNotEmpty;
    final handleMoveHorizontal = keyManager.isTab || (_controller.text.isEmpty && keyManager.isHorizontal);
    final skip = !(handleMoveDown || handleMoveHorizontal || keyManager.isF3);
    if (skip) {
      if (keyManager.isUp) {
        return KeyEventResult.handled;
      }
      return stateManager.keyManager!.eventResult.skip(
        KeyEventResult.ignored,
      );
    }
    if (handleMoveDown) {
      _moveDown(focusToPreviousCell: keyManager.isEsc);
    } else if (handleMoveHorizontal) {
      stateManager.nextFocusOfColumnFilter(
        widget.column,
        reversed: keyManager.isLeft || keyManager.isShiftPressed,
      );
    } else if (keyManager.isF3) {
      stateManager.showFilterPopup(
        _focusNode.context!,
        calledColumn: widget.column,
        onClosed: () {
          stateManager.setKeepFocus(true, notify: false);
          _focusNode.requestFocus();
        },
      );
    }
    return KeyEventResult.handled;
  }

  void _handleFocusFromRows(PlutoGridEvent plutoEvent) {
    if (!_enabled) {
      return;
    }
    if (plutoEvent is PlutoGridCannotMoveCurrentCellEvent && plutoEvent.direction.isUp) {
      var isCurrentColumn = widget.stateManager.refColumns[stateManager.columnIndexesByShowFrozen[plutoEvent.cellPosition.columnIdx!]].key == widget.column.key;
      if (isCurrentColumn) {
        stateManager.clearCurrentCell(notify: false);
        stateManager.setKeepFocus(false);
        _focusNode.requestFocus();
      }
    }
  }

  void _handleOnTap() {
    stateManager.setKeepFocus(false);
  }

  void _handleOnChanged(String changed) {
    stateManager.eventManager!.addEvent(
      PlutoGridChangeColumnFilterEvent(
        column: widget.column,
        filterType: _selectedFilter.isNotEmpty ? _resolveFilterType() : widget.column.defaultFilter,
        filterValue: changed,
        debounceMilliseconds: stateManager.configuration.columnFilter.debounceMilliseconds,
      ),
    );
  }

  PlutoFilterType _resolveFilterType() {
    switch (_selectedFilter) {
      case 'Equals':
        return PlutoFilterTypeEquals();
      case 'Does Not Equal':
        return PlutoFilterTypeDoesNotEquals();
      case 'Does Not Contain':
        return PlutoFilterTypeNotContains();
      case 'Begins With':
        return PlutoFilterTypeStartsWith();
      case 'Ends With':
        return PlutoFilterTypeEndsWith();
      case 'Greater Than':
        return PlutoFilterTypeGreaterThan();
      case 'Less Than':
        return PlutoFilterTypeLessThan();
      default:
        return PlutoFilterTypeContains();
    }
  }

  void _handleOnEditingComplete() {
    // empty for ignore event of OnEditingComplete.
  }

  Widget _buildFilterIcon({String? filterType}) {
    String selectedValue = filterType ?? _selectedFilter;
    switch (selectedValue) {
      case 'Equals':
        return Image.memory(
          base64Decode(equalsIcon),
          width: 24,
          height: 12,
          fit: BoxFit.contain,
        );
      case 'Does Not Equal':
        return Image.memory(
          base64Decode(notEqualIcon),
          width: 24,
          height: 12,
          fit: BoxFit.contain,
        );
      case 'Contains':
        return Image.memory(
          base64Decode(containIcon),
          width: 24,
          height: 12,
          fit: BoxFit.contain,
        );
      case 'Does Not Contain':
        return Image.memory(
          base64Decode(notContainIcon),
          width: 24,
          height: 12,
          fit: BoxFit.contain,
        );
      case 'Begins With':
        return Image.memory(
          base64Decode(beginsWithIcon),
          width: 24,
          height: 12,
          fit: BoxFit.contain,
        );
      case 'Ends With':
        return Image.memory(
          base64Decode(endWithIcon),
          width: 24,
          height: 12,
          fit: BoxFit.contain,
        );
      case 'Greater Than':
        return SvgPicture.string(
          greaterThanIcon,
          width: 24,
          height: 12,
          fit: BoxFit.contain,
        );
      case 'Less Than':
        return SvgPicture.string(
          lessThanIcon,
          width: 24,
          height: 12,
          fit: BoxFit.contain,
        );
      default:
        return Icon(
          Icons.delete_forever,
          color: Color(0xFF4F4F4F),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = stateManager.style;
    return OnHover(
      builder: (isHovered) => SizedBox(
        height: stateManager.columnFilterHeight,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: widget.stateManager.rows.isNotEmpty && widget.column.backgroundColor != null && widget.column.isAllColumnColored
                ? Color.alphaBlend(widget.column.backgroundColor!.withOpacity(0.6), _colorFilter)
                : _colorFilter,
            border: BorderDirectional(
              top: BorderSide(color: style.borderColor),
              end: style.enableColumnBorderVertical ? BorderSide(color: style.borderColor) : BorderSide.none,
            ),
          ),
          child: _disabledFilter != null || widget.disableFilter
              ? SizedBox()
              : Padding(
                  padding: _padding,
                  child: Align(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        SizedBox(
                          width: 20,
                          child: Theme(
                            data: Theme.of(context).copyWith(
                              scrollbarTheme: const ScrollbarThemeData().copyWith(
                                thumbColor: MaterialStateProperty.all(Color(0xFF959595)),
                                thickness: MaterialStateProperty.all(3),
                                showTrackOnHover: true,
                                trackColor: MaterialStateProperty.all(Color(0xFFE9E9E9)),
                              ),
                              hoverColor: Colors.transparent,
                            ),
                            child: StatefulBuilder(
                              builder: (_, setState) => DropdownButtonHideUnderline(
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton2<String>(
                                    dropdownPadding: EdgeInsets.all(5).copyWith(right: 10),
                                    dropdownElevation: 4,
                                    isExpanded: true,
                                    isDense: true,
                                    onMenuStateChange: (isOpen) => setState(() => isfilterMenuOpen = isOpen),
                                    // TODO add hovering effect and selected color
                                    items: (widget.column.type is PlutoColumnTypeNumber ? filteringTypesNumber : filteringTypes)
                                        .map(
                                          (String value) => DropdownMenuItem(
                                            value: value,
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              mainAxisSize: MainAxisSize.max,
                                              children: [
                                                if (value == 'Clear All Filters') ...[
                                                  Container(
                                                    alignment: Alignment.topCenter,
                                                    color: Color(0xFFE9E9E9),
                                                    height: 1,
                                                  ),
                                                  SizedBox(height: 5),
                                                ],
                                                OnHover(
                                                  builder: (isHovered) => Container(
                                                    decoration: BoxDecoration(
                                                      color: isHovered ? Color(0xffACC7DB) : Colors.transparent,
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    alignment: Alignment.center,
                                                    width: double.infinity,
                                                    height: 40,
                                                    child: Row(
                                                      children: [
                                                        SizedBox(
                                                          width: 40,
                                                          child: Align(
                                                            alignment: Alignment.center,
                                                            child: _buildFilterIcon(filterType: value),
                                                          ),
                                                        ),
                                                        Text(
                                                          value,
                                                          style: style.cellTextStyle,
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (String? value) {
                                      setState(() {
                                        if (value!.toLowerCase().contains('clear')) {
                                          widget.stateManager.removeColumnsInFilterRows(widget.stateManager.columns);
                                          // _selectedFilter = '';
                                          _controller.clear();
                                        } else
                                          _selectedFilter = value;
                                        if (_controller.text.isNotEmpty) {
                                          stateManager.removeColumnsInFilterRows(widget.stateManager.columns);
                                          _handleOnChanged(_controller.text);
                                        }
                                      });
                                    },
                                    icon: SizedBox(),
                                    hint: _selectedFilter.isEmpty
                                        ? SvgPicture.string(
                                            filterIcon,
                                            width: 24,
                                            height: 12,
                                            fit: BoxFit.contain,
                                            color: isfilterMenuOpen ? Color(0xff045692) : Color(0xFFC7C7C7),
                                          )
                                        : _buildFilterIcon(),
                                    itemPadding: EdgeInsets.zero,
                                    dropdownMaxHeight: 300,
                                    dropdownWidth: 200,
                                    dropdownDecoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(6),
                                      color: Colors.white,
                                    ),
                                    scrollbarRadius: const Radius.circular(1.5),
                                    scrollbarThickness: 3,
                                    scrollbarAlwaysShow: true,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 5),
                            child: _selectedFilter.isNotEmpty
                                ? TextField(
                                    focusNode: _focusNode,
                                    controller: _controller,
                                    enabled: _enabled,
                                    style: style.cellTextStyle,
                                    onTap: _handleOnTap,
                                    onChanged: _handleOnChanged,
                                    onEditingComplete: _handleOnEditingComplete,
                                    decoration: InputDecoration(
                                      hintText: _enabled
                                          ? _selectedFilter // widget.column.defaultFilter.title
                                          : '',
                                      hintStyle: style.cellTextStyle.copyWith(color: Color(0xFFC7C7C7)),
                                      filled: false,
                                      fillColor: _textFieldColor,
                                      border: _border,
                                      enabledBorder: _enabledBorder,
                                      disabledBorder: _disabledBorder,
                                      focusedBorder: _focusedBorder,
                                      contentPadding: const EdgeInsets.only(bottom: 10),
                                    ),
                                  )
                                : SizedBox(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

List<String> filteringTypes = [
  'Equals',
  'Does Not Equal',
  'Contains',
  'Does Not Contain',
  'Begins With',
  'Ends With',
  'Greater Than',
  'Less Than',
  'Clear All Filters',
];

List<String> filteringTypesNumber = [
  'Equals',
  'Does Not Equal',
  'Greater Than',
  'Less Than',
  'Clear All Filters',
];
const String filterIcon = '''<svg width="9" height="10" viewBox="0 0 9 10" fill="none" xmlns="http://www.w3.org/2000/svg">
<path d="M3.27891 4.753C3.37034 4.85575 3.42053 4.98998 3.42053 5.12884V9.22047C3.42053 9.46671 3.70826 9.59168 3.87857 9.41857L4.98377 8.11054C5.13167 7.92725 5.21323 7.83652 5.21323 7.65509V5.12976C5.21323 4.99091 5.26433 4.85668 5.35486 4.75391L8.52614 1.20013C8.76367 0.933526 8.58082 0.501221 8.22944 0.501221H0.404303C0.0529335 0.501221 -0.130818 0.932601 0.107611 1.20013L3.27891 4.753Z" fill="#C7C7C7"/>
</svg>''';
const String containIcon =
    '''iVBORw0KGgoAAAANSUhEUgAAABgAAAANCAYAAACzbK7QAAAACXBIWXMAAAsTAAALEwEAmpwYAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAI0SURBVHgBvdJLaBNBGAfw/27avKQPk+CrBl99aYu0VTR6EEH0pB4EEQ9qb4V6UEHRk1REEaoiCPUgaDz3ICgoioIePWjQWhBBjWlEsSlJyGvL7mb9z3Y2rNCGnvrBL1nmm51v9ptRUCeuJS4NVqtYv1DeVBEf6b+RrLMEGuolLeCUomLvQnkP8IZ/SSyywBo6RD/opTPY0bIZTY1NtUkVo4KpUhJFveAM+Wgn7SOdntGH+QocpntUpi5Ki8G+0HZ0tmyBZmpQFQVe1YeZ2QziX8dQMStiynU6Rzky6CpdoJsiqboKHKfvFKSDrnEuOI1bE1cw+mkET1LjCPsiiPhXIPF0opPpszROIVpFz+mifK4ViNJuuktf6Ki7gN8TxNbQAG1Dz/I+FPQ8Mtpf/Eyk98g1xuTUKh0RnaU/7haJ9hTpFa2kM7TOKeBjWwYiMShim74wW6PZrdI1PSSnZFz70aT/zuCY2Cjdp1YK0AFnUl7P2j0XsTrYhpPtQ+hu7YE34J2WU9bSpHzeRTvoARVUORCj1/SOXtA30SbLsjfNHwVty6K29uZuNKiNKBsl9O7vEv0uy56Li9FLD2mISs4XiMPllccwpeQusnQ+/fmXho2iLREMdgzbCaOqI8VrOpn9iE2xDaLPp2kUc2cnYopOyPOwC1ym267FRdyhR+Fo6DFvTSTgCdQSpmWiaBS5I8sZisuv7sfcNX1PM+4zyEnuyAuBZv/bWVPLEeYLFabz3m9p6eMfWJqqCa8PjDQAAAAASUVORK5CYII=''';
const String equalsIcon =
    '''iVBORw0KGgoAAAANSUhEUgAAAAwAAAANCAYAAACdKY9CAAAACXBIWXMAAAsTAAALEwEAmpwYAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAClSURBVHgBlZDBEYIwEEV3V7xTgiVYgkWIXqmAgQrQCoKxATk6WIQlWIIl5K7mu+HEiYR3Smben/27TIocbS1ATjMA/P4N1Y2zgzX6rymNThbIgTIEXKoNdcUznVMDTOg5PLK92UVlJvcZmhctZZywLswWoDwmfx/NU896bXWdEyWgtRoBoaREtEUr2ilaZUIuGuuTdeAyLr0qbMmMzZzrmZ2/V90fXHQx5pC3g8cAAAAASUVORK5CYII=''';
const String notEqualIcon =
    '''iVBORw0KGgoAAAANSUhEUgAAAAwAAAAPCAYAAADQ4S5JAAAACXBIWXMAAAsTAAALEwEAmpwYAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAGESURBVHgBhVI9TMJAFH69HomaEIFoSFzAQPyZZNHFhUgMq4PAyqIjbRMHN2R0KtRRE2FUGJxMGEhYjAOD3ZQEgoyIIQwGEml73jWhaQqRN9y7+9733r373gEsMJnnT2SA4PSM2YJSiogI8TjJybdKgO+8pr88Gyp/fFnQy5kixklFBgIiADdTfavXNH1t+yjCcXBPuXuInsV5rYT6LfCNBjBY8UIjcDCF0yxhOC8h/l41fXU3bmGEcpHBQc5J9tLK4e82jF3L0F4PWzgHpISNh0wencqqPeH85S5LXVTj+KfB0moBDB3oG4aTsqTOvJRJyGPcYXtd0zYlgE973JTVlZAjhIAp6+g5J7h/f6Dn9tevYxdBbJuBVpHqVNabLAFyxVRlvWOim8Hbw7MoID5qr+5KKRKi5PQUCPfbsDwZQ2stROX0ObsF2kUW0cKe/6R0mAfRtBLb7Xcb1qDsUjquKGCtLIh8QlFjzZpAociHf6dII10n1+C4ofEo5C2Aycl+JiywP/D7hUO6Gm4BAAAAAElFTkSuQmCC''';
const String notContainIcon =
    '''iVBORw0KGgoAAAANSUhEUgAAABgAAAANCAYAAACzbK7QAAAACXBIWXMAAAsTAAALEwEAmpwYAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAI6SURBVHgBvdPdS5NRHAfw7/O40jV1c2JZpI6oWC/0QuZLoG1J3lgRUohXCV3UXV0UdRf9Ad0UhBRUF911EQQ1CCGlhAWmIQRC4lZQ0TZtb27pHp/T91nnjCfK0ZUHPuzsvP3O+Z3zaChTxg/7h0wNvtX6DR2PguGZaJkl4CjXKXSc0wQCq042MMqfKP4zwBY6SRF6qRq93cewvr6hNMjIpJB+P4nlREw1VVI79VCBXtDkv4JdtDZNi7TVanjT7n81PzYirFLIpIWxmC3Wc58i4m1Pm3jd6g9w2C0yaYFico0ralHdFmCQ5mgDnbBHzkXnwAURDrbi483rcDb74Ny2HaFEaie7L9MT67DUSCG6JuulFDXREbpKF+gsDasA69xubOw7DWgaGnr7sBz7jlxkFtPZfLfc5F051DpJP1VR0h7gFGVphDbRJWpRASpc1WjsHygGcDb5eA9pVDhdWDJNrxySsB34pwR7gAEZ9T55yEm9pRlfv2D6/GCx7vLvwb57j+ENHoczPBWXQ6w7+yDrndRGDyjjkA0d+P1yZlVWrDQJAc36o+k6avbuL3bUdXZBr6yCkfyBQF1N6Fk8eUbmPCrnPZSpuqM2eJuWqNl2zBtW9OHdLXH1ilRZyedFampCjHfsUq9oiKyTCOkzHVULaTIlHvz5wbitzT4/tONpvcdzoKK6ttQhCgUUFhIQpkkIdk3MjLJ5Mx0kg97RPGx3kJTsJWWp1R1jRjaTJPxVuDVdW1HzvklrX34B1mLMDIqcmR8AAAAASUVORK5CYII=''';
const String beginsWithIcon =
    '''iVBORw0KGgoAAAANSUhEUgAAABgAAAANCAYAAACzbK7QAAAACXBIWXMAAAsTAAALEwEAmpwYAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAIWSURBVHgBvdNfSFNxFAfw7/Ruq2uaU6MJIihuEUGRQtswgooiilVUiD0E+RAGEhoRPSYEvdRLhIEP5Uv0UO/2kJFQD/VQYERJQZmzsrX0anO065/5/e13Ni8K80HwwIft7vzuOb977m8uo+VONwrE3OPOgvnVwgBc11dZ0421NdBR7StBtKkO3+JTePY+5lxzXKUd15P0in7KtZdCdJBmqZ/erWigivdc2I9UehY7uh5ibCKZS7XRSbKomErpM4Wl2U26LPk5ukFX6ba6uShXpXXvNnyNT8P0unGMzZbFMPmojM5TkLbLZxc9oQry01O6Jt91g5rKTYgEq9HTP4ThHxM4HW5Y3qBCCitnaYw+0T6pcU/WLdApCtB4fkTRpnok0zaef4hha7mJS0d3obaqFKOJf7kGauft5JKbLRlVpeQTjs38F8g/QUtzABvcBnovHsCJPfXY6DFwaGet8wlGKAI998Py+GqnccnXONaqdZ2yARjhoB+hgB8DQ6P4Mm5lV7iLi3Am0oAHLz46NxKS70fIlF0PUAp65iPqVuqTUd3NNmhtDiKTyaDj/iBiMpLJmTSuRBvRWLcFb3RR9TJfSwNV8CU9kkIddAv6IKhQZ/yc5OCqauvNbDY9+P4nP2+UmV74SjyYStlI9LWr01OOpbDpN807flP/k93Qx/Qt/c0lDCtpDxL0+9MxPWNnSViiUPwS6x+LcmyRq6yZ/T4AAAAASUVORK5CYII=''';
const String endWithIcon =
    '''iVBORw0KGgoAAAANSUhEUgAAABgAAAANCAYAAACzbK7QAAAACXBIWXMAAAsTAAALEwEAmpwYAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAImSURBVHgBrdLfS5NRGAfw7zvf0Spm20icMkuwBlEx+kFaVzMwKEpCWj+uEqFfF9WVdOk/EAiLIgrBi26lmwKVwggv6qblTT8u1ClSZFuuba45t/f0Pdt551H0Sh/4sL3ned/zHJ7zGNhE1ESi3YYhmjfKFwvWoIlNhAHjOn/CG+VNE+/0Ao10gaZpVFvvpAbteYHG6Yd82OasQes+P9oPB7BcsjAci+PT1O91C94mQYsU0NZfqnW5cVr9/05eM/JorP9VTFiWJRayeTGfzgkZD16MC/NyVJiX+sMObaNrNEU76Pya4t/khlRL3RSkA0da6nDvXAhDHyZR1/MMgRsDGP48g97Oo6j37Ky0SW3QRKeol25RhJ5qBXxqYxlXaY6+dp1ogcMw8GRkopywhEDk4Wu4nCZSuaVVBWSfs/SG6uk+7aUZla9VhQ3aTyly+72VUyaz+epJ8sulMjvsFl0hFz2ni7SdzmAl4nSS2tS6n7rmktlyMuBzV19sC/px92wIbpezWsD+8C19pBGaVG0ytIO0KvJ+5D0lBse+ILdUZM+PIdjoxcEmHwbudOBmxyEsForVolGSDdujnbiPMnQcK1Nkk1P2XhaVU9TzeFQk0v+EHbOJjDjdN1SdInlCjxLXCuxCZWpS6tmj5Qr0i0qyAAwRbuBdhJp3o1gSiE3PI5lRd2KV2k21SQqr469ix9q8apw1AcuBn39yNKslKp3lgK3/3VbGf7+ovf//YqvlAAAAAElFTkSuQmCC''';
const String greaterThanIcon = '''<svg width="12" height="12" viewBox="0 0 12 12" fill="none" xmlns="http://www.w3.org/2000/svg">
<defs>
<clipPath id="clip0_1798_110568">
<rect width="12" height="12" fill="white"/>
</clipPath>
</defs>
<g clip-path="url(#clip0_1798_110568)">
<path d="M0 12L12 7.5127V4.4873L0 0V3.31445L8.76762 5.99023L0 8.66602V12Z" fill="#4F4F4F"/>
</g>
</svg>''';
const String lessThanIcon = '''
<svg width="12" height="12" viewBox="0 0 12 12" fill="none" xmlns="http://www.w3.org/2000/svg">
<defs>
<clipPath id="clip0_1798_110570">
<rect width="12" height="12" fill="white" transform="translate(12 12) rotate(180)"/>
</clipPath>
</defs>
<g clip-path="url(#clip0_1798_110570)">
<path d="M12 2.68221e-07L-8.70496e-08 4.4873V7.5127L12 12V8.68555L3.23238 6.00977L12 3.33398V2.68221e-07Z" fill="#4F4F4F"/>
</g>
</svg>
''';
