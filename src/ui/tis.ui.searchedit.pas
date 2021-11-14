// -----------------------------------------------------------------
//    This file is part of Tranquil IT Software
//    Copyright (C) 2012 - 2021  Tranquil IT https://www.tranquil.it
//    All Rights Reserved.
// ------------------------------------------------------------------
unit tis.ui.searchedit;

{$i mormot.defines.inc}

interface

uses
  Classes,
  SysUtils,
  Forms,
  Controls,
  Graphics,
  Dialogs,
  StdCtrls,
  ExtCtrls,
  Buttons,
  tis.ui.parts.buttons;

type
  /// event when click in a button of the collection
  TOnButtonClick = procedure (Sender: TObject; aButton: TButtonItem) of object;

  /// event triggered before searching a text typed by the user
  TOnBeforeSearch = procedure(Sender: TObject; const aText: string; var aAbort: Boolean) of object;

  /// event triggered when user is searching a text
  TOnSearch = procedure(Sender: TObject; const aText: string) of object;

  /// component that allow user searching a typed text in asynchronous mode
  // - it will use an internal TTimer instance
  TTisSearchEdit = class(TComboBox, IButtonProperties)
  private
    fTimer: TTimer;
    fButtons: TButtonCollection;
    fAutoSearch: Boolean;
    fSearchMaxHistory: Integer;
    fOnButtonClick: TOnButtonClick;
    fOnBeforeSearch: TOnBeforeSearch;
    fOnSearch: TOnSearch;
    procedure SetDefault;
    procedure SetUpEdit;
    // -------- Timer events --------
    function GetSearchInterval: Cardinal;
    procedure SetSearchInterval(aValue: Cardinal);
    function GetOnStartSearch: TNotifyEvent;
    procedure SetOnStartSearch(aValue: TNotifyEvent);
    function GetOnStopSearch: TNotifyEvent;
    procedure SetOnStopSearch(aValue: TNotifyEvent);
  protected
    const DefaultSearchMaxHistory = 8;
    const DefaultSearchInterval = 1000;
  protected
    // ------------------------------- inherited methods ----------------------------------
    procedure Loaded; override;
    procedure SetParent(aNewParent: TWinControl); override;
    procedure DoSetBounds(aLeft, aTop, aWidth, aHeight: Integer); override;
    // ------------------------------- new methods ----------------------------------
    /// it triggers OnBeforeSearch event
    function DoBeforeSearch: Boolean; virtual;
    /// it triggers OnSearch event
    // - first it will test DoBeforeSearch result
    procedure DoSearch(Sender: TObject); virtual;
    /// it triggers button clicks
    procedure DoButtonClick(Sender: TObject); virtual;
    /// it implements IButtonProperties.Setup
    procedure Setup(aButton: TButtonItem); virtual;
  public
    // ------------------------------- inherited methods ----------------------------------
    constructor Create(aOwner: TComponent); override;
    destructor Destroy; override;
    /// it triggers RefreshSearch if aKey=#13, even if AutoSearch=TRUE
    procedure KeyPress(var aKey: char); override;
    // ------------------------------- new methods ----------------------------------
    /// it triggers OnSearch event directly, even if AutoSearch=TRUE
    // - you might want to use RefreshSearch instead, for do not bypass AutoSearch flag
    procedure Search; virtual;
    /// it will refresh the search
    // - if AutoSearch=TRUE it will enable the timer, otherwise it will call Search directly
    procedure RefreshSearch; virtual;
  published
    // ------------------------------- new properties ----------------------------------
    /// if TRUE, it will start the Timer when user start typing
    property AutoSearch: Boolean read fAutoSearch write fAutoSearch default True;
    /// a collection of buttons
    property Buttons: TButtonCollection read fButtons write fButtons;
    /// the max history items that it will keep
    property SearchMaxHistory: Integer read fSearchMaxHistory write fSearchMaxHistory default DefaultSearchMaxHistory;
    /// the interval of the internal Timer
    property SearchInterval: Cardinal read GetSearchInterval write SetSearchInterval default DefaultSearchInterval;
    // ------------------------------- new events ----------------------------------
    /// an event that will be trigger for bkCustom Kind buttons
    property OnButtonClick: TOnButtonClick read fOnButtonClick write fOnButtonClick;
    /// an event that will be trigger before start searching
    // - you have an option to abort the operation
    property OnBeforeSearch: TOnBeforeSearch read fOnBeforeSearch write fOnBeforeSearch;
    /// an event that will be trigger when the Timer starts
    property OnStartSearch: TNotifyEvent read GetOnStartSearch write SetOnStartSearch;
    /// an event that will call the user's algorithm for searching
    property OnSearch: TOnSearch read fOnSearch write fOnSearch;
    /// an event that will be trigger when the Timer stops
    property OnStopSearch: TNotifyEvent read GetOnStopSearch write SetOnStopSearch;
  end;

implementation

{ TTisSearchEdit }

procedure TTisSearchEdit.SetDefault;
begin
  Width := 130;
  Height := 24;
end;

procedure TTisSearchEdit.SetUpEdit;
begin
  Text := '';
  ControlStyle := ControlStyle - [csSetCaption];
end;

function TTisSearchEdit.GetSearchInterval: Cardinal;
begin
  result := fTimer.Interval;
end;

procedure TTisSearchEdit.SetSearchInterval(aValue: Cardinal);
begin
  fTimer.Interval := aValue;
end;

function TTisSearchEdit.GetOnStartSearch: TNotifyEvent;
begin
  result := fTimer.OnStartTimer;
end;

procedure TTisSearchEdit.SetOnStartSearch(aValue: TNotifyEvent);
begin
  fTimer.OnStartTimer := aValue;
end;

function TTisSearchEdit.GetOnStopSearch: TNotifyEvent;
begin
  result := fTimer.OnStopTimer;
end;

procedure TTisSearchEdit.SetOnStopSearch(aValue: TNotifyEvent);
begin
  fTimer.OnStopTimer := aValue;
end;

procedure TTisSearchEdit.Loaded;
begin
  inherited Loaded;
  fButtons.Invalidate;
end;

procedure TTisSearchEdit.SetParent(aNewParent: TWinControl);
begin
  inherited SetParent(aNewParent);
  if csDestroying in ComponentState then
    exit;
  fButtons.Invalidate;
end;

procedure TTisSearchEdit.DoSetBounds(aLeft, aTop, aWidth, aHeight: Integer);
begin
  inherited DoSetBounds(aLeft, aTop, aWidth, aHeight);
  if Assigned(fButtons) then
    fButtons.Invalidate;
end;

function TTisSearchEdit.DoBeforeSearch: Boolean;
var
  aborted: Boolean;
begin
  aborted := False;
  if Assigned(fOnBeforeSearch) then
    fOnBeforeSearch(self, Text, aborted);
  result := not aborted;
end;

procedure TTisSearchEdit.DoSearch(Sender: TObject);
begin
  fTimer.Enabled := False;
  if DoBeforeSearch and Assigned(fOnSearch) then
    fOnSearch(self, Text);
end;

procedure TTisSearchEdit.DoButtonClick(Sender: TObject);
var
  b: TButtonItem;
begin
  b := fButtons.Items[(Sender as TComponent).Tag];
  case b.Kind of
    bkCustom:
      if Assigned(fOnButtonClick) then
        fOnButtonClick(self, b);
    bkSearch:
    begin
      RefreshSearch;
      AddHistoryItem(Text, fSearchMaxHistory, True,
        cbactSearchCaseSensitive in AutoCompleteText);
    end;
    bkClear:
      Clear;
  end;
end;

procedure TTisSearchEdit.Setup(aButton: TButtonItem);
begin
  aButton.Button.OnClick := DoButtonClick;
end;

constructor TTisSearchEdit.Create(aOwner: TComponent);
begin
  inherited Create(aOwner);
  fTimer := TTimer.Create(nil);
  fTimer.OnTimer := DoSearch;
  fButtons := TButtonCollection.Create(self);
  fAutoSearch := True;
  fSearchMaxHistory := DefaultSearchMaxHistory;
  SetDefault;
  SetUpEdit;
end;

destructor TTisSearchEdit.Destroy;
begin
  fTimer.Free;
  fButtons.Free;
  inherited Destroy;
end;

procedure TTisSearchEdit.KeyPress(var aKey: char);
begin
  inherited KeyPress(aKey);
  fTimer.Enabled := fAutoSearch;
  if aKey = #13 then
  begin
    RefreshSearch;
    AddHistoryItem(Text, fSearchMaxHistory, True,
      cbactSearchCaseSensitive in AutoCompleteText);
  end;
end;

procedure TTisSearchEdit.Search;
begin
  DoSearch(self);
end;

procedure TTisSearchEdit.RefreshSearch;
begin
  if fAutoSearch then
    fTimer.Enabled := True
  else
    Search;
end;

end.
