unit SEHR.DashBoard;

{$DEFINE TEST}

interface

uses
  Winapi.Windows,
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.Threading,
  System.Types,
  IdHttp,
  IdSSLOpenSSL,
  Vcl.Graphics,
  Vcl.Controls,
  Vcl.ExtCtrls,
  Vcl.Menus,
  Vcl.Forms,
  SEHR.JsonDataObjects,
  SEHR.APIClient,
  SEHR.TrendChart,
  Redis.Client,
  Redis.NetLib.INDY,
  Redis.Commons,
  SynDB,
  SynDBOracle;

type
  TDashBoard = class;
  TCustomMonitorItem = class;

  TItemState = (
    ssNone,
    ssRunning,
    ssUnreadable,
    ssSuccess,
    ssFail
  );

  TLinkPosition = (
    lpTopLeft,
    lpTopCenter,
    lpTopRight,
    lpLeft,
    lpRight,
    lpBottomLeft,
    lpBottomCenter,
    lpBottomRight
  );

  TCustomMonitorItem = class(TCustomControl)
  private
    FBorderWidth: Integer;
    FChart: TTrendChart;
    FData: TStrings;
    FLapTime: Int64;
    FLastTime: TDateTime;
    FRunning: Boolean;
    FOldState: TItemState;
    FState: TItemState;
    FSubTitle: string;
    FSubtitleFont: TFont;
    FTitle: string;
    FTitleFont: TFont;

    function  GetDashBoard: TDashBoard;
    procedure SetData(const Value: TStrings);
    procedure SetState(const Value: TItemState);
    procedure SetSubTitle(const Value: string);
    procedure SetSubTitleFont(const Value: TFont);
    procedure SetTitle(const Value: string);
    procedure SetTitleFont(const Value: TFont);
  protected
    procedure DrawBorder; virtual;
    function  InternalExecute: TItemState; virtual;
    procedure Paint; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure Execute; virtual;
    procedure FromJSON(AJSON: TJSONObject); virtual;
    function  ToJSON: TJSONObject; virtual;

    property Chart: TTrendChart read FChart;
    property DashBoard: TDashBoard read GetDashBoard;
    property LapTime: Int64 read FLapTime write FLapTime;
    property LastTime: TDateTime read FLastTime write FLastTime;
    property Running: Boolean read FRunning write FRunning;
    property State: TItemState read FState write SetState;
  published
    property BorderWidth: Integer read FBorderWidth write FBorderWidth default 4;
    property Data: TStrings read FData write SetData;
    property SubTitle: string read FSubTitle write SetSubTitle;
    property SubTitleFont: TFont read FSubTitleFont write SetSubTitleFont;
    property Title: string read FTitle write SetTitle;
    property TitleFont: TFont read FTitleFont write SetTitleFont;

    // inherited
    property Color;
    property Constraints;
    property ParentFont;
  end;

  TWEBMonitor = class(TCustomMonitorItem)
  protected
    function  InternalExecute: TItemState; override;
  public
    constructor Create(AOwner: TComponent); override;
  end;

  TWASMonitor = class(TCustomMonitorItem)
  protected
    function  InternalExecute: TItemState; override;
  public
    constructor Create(AOwner: TComponent); override;
  end;

  TAPIMMonitor = class(TCustomMonitorItem)
  protected
    function  InternalExecute: TItemState; override;
  public
    constructor Create(AOwner: TComponent); override;
  end;

  TOracleMonitor = class(TCustomMonitorItem)
  protected
    function  InternalExecute: TItemState; override;
  public
    constructor Create(AOwner: TComponent); override;
  end;

  TRedisMonitor = class(TCustomMonitorItem)
  protected
    function  InternalExecute: TItemState; override;
  public
    constructor Create(AOwner: TComponent); override;
  end;

  TLinkItem = class(TCollectionItem)
  private
    FPen: TPen;
    FSource: TControl;
    FSourcePosition: TLinkPosition;
    FTarget: TControl;
    FTargetPosition: TLinkPosition;

    procedure SetPen(const Value: TPen);
  protected
    function  GetDisplayName: string; override;
  public
    constructor Create(Collection: TCollection); override;
    destructor Destroy; override;

    procedure Draw(ACanvas: TCanvas); virtual;
  published
    property Pen: TPen read FPen write SetPen;
    property Source: TControl read FSource write FSource;
    property SourcePosition: TLinkPosition read FSourcePosition write FSourcePosition;
    property Target: TControl read FTarget write FTarget;
    property TargetPosition: TLinkPosition read FTargetPosition write FTargetPosition;
  end;

  TLinks = class(TOwnedCollection)
  private
    function  GetItem(Index: Integer): TLinkItem;
    procedure SetItem(Index: Integer; const Value: TLinkItem);
  protected
    procedure Update(Item: TCollectionItem); override;
  public
    function  Add: TLinkItem;

    property Items[Index: Integer]: TLinkItem read GetItem write SetItem; default;
  end;

  TCountDownEvent = procedure(Sender: TObject; ACurrent: Integer) of object;
  TEditEvent = procedure(Sender: TObject) of object;

  TDashBoard = class(TCustomControl)
  strict private
    const
      CMD_START = 10;
      CMD_STOP = 11;
      CMD_SAVE = 20;
      CMD_LOAD = 21;
      CMD_EXIT = 30;

      ONE_SECOND = 1000;

      DEFAULT_INTERVAL = 30; //30 secs

    type
      TColors = class(TPersistent)
      private
        FFail: TColor;
        FNormal: TColor;
        FRunning: TColor;
        FSuccess: TColor;

        FOnChanged: TNotifyEvent;

        function  GetColor(const Index: Integer): TColor;
        procedure SetColor(const Index: Integer; const Value: TColor);
      protected
        procedure DoChange;
      public
        constructor Create;
      published
        property Fail: TColor index 0 read GetColor write SetColor;
        property Normal: TColor index 1 read GetColor write SetColor;
        property Running: TColor index 2 read GetColor write SetColor;
        property Success: TColor index 3 read GetColor write SetColor;

        property OnChanged: TNotifyEvent read FOnChanged write FOnChanged;
      end;

  private
    FColors: TColors;
    FCount: Integer;
    FInterval: Integer;
    FLinks: TLinks;
    FPopupMenu: TPopupMenu;
    FTimer: TTimer;

    FOnCountDown: TCountDownEvent;
    FOnEdit: TEditEvent;
    FOnStart: TNotifyEvent;
    FOnStop: TNotifyEvent;

    procedure Clear;
    procedure CreatePopupMenu;
    procedure DoColorChange(Sender: TObject);
    procedure DoCountDown;
    procedure DoMenu(Sender: TObject);
    procedure DoEdit(Sender: TObject);
    procedure DoTimer(Sender: TObject);
    procedure DrawLines;
    function  GetInterval: Integer;
    procedure SetInterval(const Value: Integer);
  protected
    procedure CreateParams(var Params: TCreateParams); override;
    procedure Loaded; override;
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
    procedure Paint; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure ForEach(AProc: TProc<TCustomMonitorItem>);
    procedure LoadFromFile;
    procedure SaveToFile;
    procedure Start;
    procedure Stop;

    property Timer: TTimer read FTimer;
  published
    property Colors: TColors read FColors write FColors;
    property Interval: Integer read GetInterval write SetInterval;
    property Links: TLinks read FLinks write FLinks;

    property Align;
    property DoubleBuffered;
    property Font;
    property ParentFont;

    property OnCountDown: TCountDownEvent read FOnCountDown write FOnCountDown;
    property Onedit: TEditEvent read FOnEdit write FOnEdit;
    property OnStart: TNotifyEvent read FOnStart write FOnStart;
    property OnStop: TNotifyEvent read FOnStop write FOnStop;
  end;

  function CreateHttpClient(const AUseSSL: Boolean; const AContentType: string): TIdHttp;

  procedure Register;

implementation

uses
  System.Diagnostics,
  SEHR.IniCrypt;

procedure Register;
begin
  RegisterComponents('SEHR DashBoard', [
    TDashBoard,
    TWEBMonitor,
    TWASMonitor,
    TAPIMMonitor,
    TOracleMonitor,
    TRedisMonitor
  ]);
end;

{$REGION 'helper'}
function CreateHttpClient(const AUseSSL: Boolean; const AContentType: string): TIdHttp;
var
  LSSLHandler: TIdSSLIOHandlerSocketOpenSSL;
begin
  Result := TIdHttp.Create(nil);
  with Result do
  begin
    HTTPOptions := HTTPOptions + [hoInProcessAuth];
    Request.BasicAuthentication := False;
    Request.ContentEncoding := 'utf-8';
    Request.ContentType := AContentType;
    HandleRedirects := True;
    ConnectTimeout := 2 * 1000;
    Request.UserAgent := 'system monitoring';
  end;

  if AUseSSL then
  begin
    LSSLHandler := TIdSSLIOHandlerSocketOpenSSL.Create(Result);
    LSSLHandler.SSLOptions.VerifyMode := [];
    LSSLHandler.SSLOptions.VerifyDepth := 0;
    LSSLHandler.SSLOptions.Method := sslvTLSv1_2;
    LSSLHandler.SSLOptions.Mode := sslmUnassigned;

    Result.IOHandler := LSSLHandler;
  end;
end;

procedure DSiTrimWorkingSet;
var
  hProcess: THandle;
begin
  hProcess := OpenProcess(PROCESS_SET_QUOTA, false, GetCurrentProcessId);
  try
    SetProcessWorkingSetSize(hProcess, $FFFFFFFF, $FFFFFFFF);
  finally
    CloseHandle(hProcess);
  end;
end;

{$ENDREGION}

{$REGION 'TCustomMonitorItem'}

constructor TCustomMonitorItem.Create(AOwner: TComponent);
begin
  inherited;

  Width := 150;
  Height := 100;
  Color := clWhite;
  Constraints.MinHeight := 100;
  Constraints.MinWidth := 150;

  FBorderWidth := 4;
  FChart := TTrendChart.Create(Self);
  FChart.Parent := Self;
  FChart.SetBounds(8, 50, 134, 30);
  FChart.SetSubComponent(True);

  FData := TStringList.Create;
  FState := ssNone;
  FSubTitle := '';
  FSubTitleFont := TFont.Create;
  FSubTitleFont.Size := 8;
  FTitle := '';
  FTitleFont := TFont.Create;
  FTitleFont.Size := 18;
  FTitleFont.Style := [fsBold];
end;

destructor TCustomMonitorItem.Destroy;
begin
  FChart.Free;
  FData.Free;
  FSubTitleFont.Free;
  FTitleFont.Free;

  inherited;
end;

procedure TCustomMonitorItem.DrawBorder;
var
  LRect: TRect;
begin
  case FState of
  ssNone:
    Canvas.Brush.Color := DashBoard.Colors.Normal;
  ssRunning:
    Canvas.Brush.Color := DashBoard.Colors.Running;
  ssUnreadable:
    Canvas.Brush.Color := DashBoard.Colors.Fail;
  ssSuccess:
    Canvas.Brush.Color := DashBoard.Colors.Success;
  ssFail:
    Canvas.Brush.Color := DashBoard.Colors.Fail;
  end;

  LRect := Rect(0, 0, Width, Height);
  Canvas.FillRect(LRect);

  LRect.Inflate(-FBorderWidth, -FBorderWidth);
  if (FOldState = ssUnreadable) or (FOldState = ssFail) or (FState = ssUnreadable) or (FState = ssFail) then
    Canvas.Brush.Color := DashBoard.Colors.Fail
  else
    Canvas.Brush.Color := Color;

  Canvas.FillRect(LRect);
end;

procedure TCustomMonitorItem.Execute;
var
  LStopWatch: TStopWatch;
begin
  if Running then
    Exit;

  FRunning := True;
  State := ssRunning;
  TTask.Run(
    procedure
    var
      LState: TitemState;
    begin
      LStopWatch := TStopWatch.StartNew;
      LState := InternalExecute;
      LStopWatch.Stop;

      FLapTime := LStopWatch.ElapsedMilliseconds;
      FLastTime := Now;

      if (LState = ssSuccess) then
        FChart.Add(FLapTime)
      else
        FChart.Add(0);

      FRunning := False;
      State := LState;
    end
  ).Start;
end;

procedure TCustomMonitorItem.FromJSON(AJSON: TJSONObject);
var
  i: Integer;
  LName: string;
begin
  // ��Ʈ�� �⺻����
  Color := AJSON.I['color'];

  // �ΰ�����
  FTitle := AJSON.S['title'];
  FSubTitle := AJSON.S['subtitle'];

  for i := 0 to FData.Count-1 do
  begin
    LName := FData.Names[i];
    FData.Values[LName] := TIniCrypt.Decode(AJSON.O['data'].S[LName]);
  end;

  Invalidate;
end;

function TCustomMonitorItem.GetDashBoard: TDashBoard;
begin
  Result := TDashBoard(Parent);
end;

function TCustomMonitorItem.InternalExecute: TItemState;
begin
  Result := ssSuccess;
end;

procedure TCustomMonitorItem.Paint;
var
  LRect: TRect;
  LText: string;
  LTextHeight: Integer;
begin
  DrawBorder;

  // title
  Canvas.Font.Assign(FTitleFont);
  Canvas.TextOut(8, 5, FTitle);
  LTextHeight := Canvas.TextHeight(FTitle);

  // sub-title
  Canvas.Font.Assign(FSubTitleFont);
  Canvas.TextOut(8, 3 + LTextHeight + 2, FSubTitle);

  // state
  if FState = ssSuccess then
  begin
    LRect := Rect(8, Height-18, Width-10, Height-4);
    LText := Format('%s (%d ms)', [FormatDateTime('hh:nn:ss', FLastTime), FLapTime]);

    Canvas.Font.Assign(FSubTitleFont);
    Canvas.Font.Color := clGray;
    Canvas.TextRect(LRect, LText, [tfVerticalCenter, tfRight]);
  end;
end;

procedure TCustomMonitorItem.SetData(const Value: TStrings);
begin
  FData.Assign(Value);
end;

procedure TCustomMonitorItem.SetState(const Value: TItemState);
begin
  if (FState <> Value) then
  begin
    if (Value <> ssNone) then
      FOldState := FState;
    FState := Value;
    Invalidate;
  end;
end;

procedure TCustomMonitorItem.SetSubTitle(const Value: string);
begin
  if (FSubTitle <>  Value) then
  begin
    FSubTitle := Value;
    Invalidate;
  end;
end;

procedure TCustomMonitorItem.SetSubTitleFont(const Value: TFont);
begin
  FSubTitleFont.Assign(Value);
  Invalidate;
end;

procedure TCustomMonitorItem.SetTitle(const Value: string);
begin
  if (FTitle <> Value) then
  begin
    FTitle := Value;
    Invalidate;
  end;
end;

procedure TCustomMonitorItem.SetTitleFont(const Value: TFont);
begin
  FTitleFont.Assign(Value);
  Invalidate;
end;

function TCustomMonitorItem.ToJSON: TJSONObject;
var
  i: Integer;
begin
  Result := TJSONObject.Create;
  Result.S['name'] := Name;
  Result.S['title'] := FTitle;
  Result.S['subtitle'] := FSubTitle;
  Result.I['color'] := Color;
  for i := 0 to FData.Count-1 do
    Result.O['data'].S[FData.Names[i]] := TIniCrypt.Encode(FData.ValueFromIndex[i]);
end;

{$ENDREGION}

{$REGION 'TWEBMonitor'}

constructor TWEBMonitor.Create(AOwner: TComponent);
begin
  inherited;

  Data.Add('url=');
end;

function TWEBMonitor.InternalExecute: TItemState;
var
  LHttpClient: TIdHttp;
  LStream: TStringStream;
begin
  Result := ssSuccess;
  LHttpClient := CreateHttpClient(FData.Values['url'].StartsWith('https://'), 'application/x-www-form-urlencoded');
  LStream := TStringStream.Create('', TEncoding.UTF8);
  try
    try
      LHttpClient.Get(FData.Values['url'], LStream);
      if (LHttpClient.ResponseCode <> 200) then
        Result := ssFail;
    except
      Result := ssUnreadable;
    end;
  finally
    LStream.Free;
    LHttpClient.Free;
  end;
end;

{$ENDREGION}

{$REGION 'TWASMonitor'}

constructor TWASMonitor.Create(AOwner: TComponent);
begin
  inherited;

  Data.Add('url=');
end;

function TWASMonitor.InternalExecute: TItemState;
var
  LHttpClient: TIdHttp;
  LStream: TStringStream;
  LResponse: string;
begin
  LHttpClient := CreateHttpClient(FData.Values['url'].StartsWith('https://'), 'application/json');
  LHttpClient.Request.ContentType := 'application/json';
  LStream := TStringStream.Create('', TEncoding.UTF8);
  try
    try
      LResponse := LHttpClient.Post(FData.Values['url'], LStream);
      if (LHttpClient.ResponseCode = 200) and LResponse.Contains('"result":"success"') then
        Result := ssSuccess
      else
        Result := ssFail;
    except
      Result := ssUnreadable;
    end;
  finally
    LStream.Free;
    LHttpClient.Free;
  end;
end;

{$ENDREGION}

{$REGION 'TAPIMMonitor'}

constructor TAPIMMonitor.Create(AOwner: TComponent);
begin
  inherited;

  Data.Add('url=');
  Data.Add('token=');
  Data.Add('param=');
  Data.Add('key=');
end;

function TAPIMMonitor.InternalExecute: TItemState;
var
  LAPIClient: TAPIClient;
  LAPIService: IAPIService;
begin
  LAPIClient := TAPIClient.Create;
  LAPIService := TAPIService.Create;
  try
    LAPIService.Request.S['userid'] := FData.Values['param'];
    try
      LAPIClient.SendRequest(LAPIService, FData.Values['url'], FData.Values['token'], FData.Values['key']);
      if LAPIService.ResponseCode = 200 then
        Result := ssSuccess
      else
        Result := ssFail;
    except
      Result := ssUnreadable;
    end;
  finally
    LAPIClient.Free;
  end;
end;

{$ENDREGION}

{$REGION 'TOracleMonitor'}

constructor TOracleMonitor.Create(AOwner: TComponent);
begin
  inherited;

  Data.Add('server=');
  Data.Add('user=');
  Data.Add('password=');
end;

function TOracleMonitor.InternalExecute: TItemState;
var
  LProp: TSQLDBOracleConnectionProperties;
  LConnection: TSQLDBOracleConnection;
  LStatement: TSQLDBStatement;
begin
  LProp := TSQLDBOracleConnectionProperties.Create(FData.Values['server'], '', FData.Values['user'], FData.Values['password']);
  LConnection := TSQLDBOracleConnection.Create(LProp);
  try
    try
      LConnection.Connect;
      if LConnection.Connected then
      begin
        LStatement := LConnection.NewStatement;
        LStatement.Execute('select TO_CHAR(SYSDATE, ''MM-DD-YYYY HH24:MI:SS'') "NOW" FROM DUAL;', True);
        LConnection.Disconnect;
        Result := ssSuccess;
      end
      else
        Result := ssUnreadable;
    except
      Result := ssUnreadable;
    end;
  finally
    LProp.Free;
    LConnection.Free;
  end;
end;

{$ENDREGION}

{$REGION 'TRedisMonitor'}

constructor TRedisMonitor.Create(AOwner: TComponent);
begin
  inherited;

  Data.Add('ip=');
  Data.Add('port=');
  Data.Add('password=');
end;

function TRedisMonitor.InternalExecute: TItemState;
var
  LClient: IRedisClient;
  LCommand: IRedisCommand;
  LResult: String;
begin
  LClient := NewRedisClient(FData.Values['ip'], FData.Values['port'].ToInteger);
  try
    if (LClient <> nil) then
    begin
      try
        if (FData.Values['password'] <> '') then
          LClient.AUTH(FData.Values['password']);

        LCommand := NewRedisCommand('PING');
        LResult := LClient.ExecuteWithStringResult(LCommand);
        if SameText(LResult, 'PONG') then
          Result := ssSuccess
        else
          Result := ssFail;
      except
        Result := ssUnreadable;
      end;
    end
    else
      Result := ssUnreadable;
  finally
    LClient := nil;
  end;
end;

{$ENDREGION}

{$REGION 'TLinkItem'}

constructor TLinkItem.Create(Collection: TCollection);
begin
  inherited;

  FPen := TPen.Create;
  FPen.Style := psDot;
  FPen.Color := clYellow;
  FPen.Width := 1;

  FSource := nil;
  FSourcePosition := lpRight;
  FTarget := nil;
  FTargetPosition := lpLeft;
end;

destructor TLinkItem.Destroy;
begin
  FSource := nil;
  FTarget := nil;

  inherited;
end;

procedure TLinkItem.Draw(ACanvas: TCanvas);
var
  LRect: TRect;
  LSourcePoint: TPoint;
  LTargetPoint: TPoint;
begin
  if (FSource <> nil) and (FTarget <> nil) then
  begin
    // ������ ������
    LRect := FSource.BoundsRect;
    case FSourcePosition of
    lpTopLeft:
      LSourcePoint := Point(LRect.Left, LRect.Top);
    lpTopCenter:
      LSourcePoint := Point(LRect.Left + LRect.Width div 2, LRect.Top);
    lpTopRight:
      LSourcePoint := Point(LRect.Left, LRect.Right);
    lpLeft:
      LSourcePoint := Point(LRect.Left, LRect.Top + LRect.Height div 2);
    lpRight:
      LSourcePoint := Point(LRect.Right, LRect.Top + LRect.Height div 2);
    lpBottomLeft:
      LSourcePoint := Point(LRect.Left, LRect.Bottom);
    lpBottomCenter:
      LSourcePoint := Point(LRect.Left + LRect.Width div 2, LRect.Bottom);
    lpBottomRight:
      LSourcePoint := Point(LRect.Right, LRect.Bottom);
    end;

    // ������ ����
    LRect := FTarget.BoundsRect;
    case FTargetPosition of
    lpTopLeft:
      LTargetPoint := Point(LRect.Left, LRect.Top);
    lpTopCenter:
      LTargetPoint := Point(LRect.Left + LRect.Width div 2, LRect.Top);
    lpTopRight:
      LTargetPoint := Point(LRect.Left, LRect.Right);
    lpLeft:
      LTargetPoint := Point(LRect.Left, LRect.Top + LRect.Height div 2);
    lpRight:
      LTargetPoint := Point(LRect.Right, LRect.Top + LRect.Height div 2);
    lpBottomLeft:
      LTargetPoint := Point(LRect.Left, LRect.Bottom);
    lpBottomCenter:
      LTargetPoint := Point(LRect.Left + LRect.Width div 2, LRect.Bottom);
    lpBottomRight:
      LTargetPoint := Point(LRect.Right, LRect.Bottom);
    end;

    ACanvas.Pen.Assign(FPen);
    ACanvas.MoveTo(LSourcePoint.X, LSourcePoint.Y);
    ACanvas.LineTo(LTargetPoint.X, LTargetPoint.Y);
  end;
end;

function TLinkItem.GetDisplayName: string;
begin
  if (FSource <> nil) and (FTarget <> nil) then
    Result := Format('%s -> %s', [FSource.Name, FTarget.Name])
  else
    Result := Format('item %d', [Index]);
end;

procedure TLinkItem.SetPen(const Value: TPen);
begin
  FPen.Assign(Value);
end;

{$ENDREGION}

{$REGION 'TLinks'}

function TLinks.Add: TLinkItem;
begin
  Result := TLinkItem(inherited Add);
end;

function TLinks.GetItem(Index: Integer): TLinkItem;
begin
  Result := TLinkItem(inherited Items[Index]);
end;

procedure TLinks.SetItem(Index: Integer; const Value: TLinkItem);
begin
  inherited Items[Index] := Value;
end;

procedure TLinks.Update(Item: TCollectionItem);
begin
  inherited;

  TDashBoard(Owner).Invalidate;
end;

{$ENDREGION}

{$REGION 'TDashBoard.TColors'}

constructor TDashBoard.TColors.Create;
begin
  FFail := clRed;
  FNormal := clWhite;
  FRunning := clGreen;
  FSuccess := clBlue;
end;

procedure TDashBoard.TColors.DoChange;
begin
  if Assigned(FOnChanged) then
    FOnChanged(Self);
end;

function TDashBoard.TColors.GetColor(const Index: Integer): TColor;
begin
  Result := FSuccess;
  case Index of
  0:
    Result := FFail;
  1:
    Result := FNormal;
  2:
    Result := FRunning;
  3:
    Result := FSuccess;
  end;
end;

procedure TDashBoard.TColors.SetColor(const Index: Integer; const Value: TColor);
begin
  case Index of
  0:
    if (FFail <> Value) then
    begin
      FFail := Value;
      DoChange;
    end;
  1:
    if (FNormal <> Value) then
    begin
      FNormal := Value;
      DoChange;
    end;
  2:
    if (FRunning <> Value) then
    begin
      FRunning := Value;
      Dochange;
    end;
  3:
    if (FSuccess <> Value) then
    begin
      FSuccess := Value;
      DoChange;
    end;
  end;
end;

{$ENDREGION}

{$REGION 'TDashBoard'}

constructor TDashBoard.Create(AOwner: TComponent);
begin
  inherited;

  ControlStyle := [csAcceptsControls, csCaptureMouse, csClickEvents,
    csSetCaption, csOpaque, csDoubleClicks, csReplicatable, csPannable, csGestures];

  FColors := TColors.Create;
  FColors.OnChanged := DoColorChange;

  FLinks := TLinks.Create(Self, TLinkItem);
  FInterval := 10000;

  FTimer := TTimer.Create(nil);
  FTimer.Interval := ONE_SECOND;
  FTimer.Enabled := False;
  FTimer.OnTimer := DoTimer;

  CreatePopupMenu;
end;

destructor TDashBoard.Destroy;
begin
  Clear;

  FColors.Free;
  FLinks.Free;
  FPopupMenu.Free;
  FTimer.Free;

  inherited;
end;

procedure TDashBoard.Clear;
begin
  Invalidate;
end;

procedure TDashBoard.CreateParams(var Params: TCreateParams);
begin
  inherited;
end;

procedure TDashBoard.CreatePopupMenu;
var
  LItem: TMenuItem;
begin
  FPopupMenu := TPopupMenu.Create(nil);
  FPopupMenu.AutoHotkeys := maManual;

  LItem := TMenuItem.Create(FPopupMenu);
  LItem.Caption := '����(&S)';
  LItem.Tag := CMD_START;
  LItem.OnClick := DoMenu;
  FPopupMenu.Items.Add(LItem);

  LItem := TMenuItem.Create(FPopupMenu);
  LItem.Caption := '����(&T)';
  LItem.Tag := CMD_STOP;
  LItem.OnClick := DoMenu;
  FPopupMenu.Items.Add(LItem);

{$IFDEF TEST}
  LItem := TMenuItem.Create(FPopupMenu);
  LItem.Caption := '-';
  FPopupMenu.Items.Add(LItem);

  LItem := TMenuItem.Create(FPopupMenu);
  LItem.Caption := '����(&S)';
  LItem.Tag := CMD_SAVE;
  LItem.OnClick := DoMenu;
  FPopupMenu.Items.Add(LItem);

  LItem := TMenuItem.Create(FPopupMenu);
  LItem.Caption := '�ҷ�����(&O)';
  LItem.Tag := CMD_LOAD;
  LItem.OnClick := DoMenu;
  FPopupMenu.Items.Add(LItem);
{$ENDIF}

  LItem := TMenuItem.Create(FPopupMenu);
  LItem.Caption := '-';
  FPopupMenu.Items.Add(LItem);

  LItem := TMenuItem.Create(FPopupMenu);
  LItem.Caption := '����(&X)';
  LItem.Tag := CMD_EXIT;
  LItem.OnClick := DoMenu;
  FPopupMenu.Items.Add(LItem);

  PopupMenu := FPopupMenu;
end;

procedure TDashBoard.DoColorChange(Sender: TObject);
begin
  ForEach(
    procedure(AItem: TCustomMonitorItem)
    begin
      AItem.Invalidate;
    end
  );
end;

procedure TDashBoard.DoCountDown;
begin
  if Assigned(FOnCountDown) then
    FOnCountDown(Self, FCount);
end;

procedure TDashBoard.DoEdit(Sender: TObject);
begin
  if Assigned(FOnEdit) then
    FOnEdit(Sender);
end;

procedure TDashBoard.DoMenu(Sender: TObject);
var
  LItem: TMenuItem;
begin
  LItem := TMenuitem(Sender);
  case LItem.Tag of
  CMD_START:
    begin
      Start;
    end;
  CMD_STOP:
    begin
      Stop;
    end;
  CMD_SAVE:
    begin
      SaveToFile;
    end;
  CMD_LOAD:
    begin
      LoadFromFile;
    end;
  CMD_EXIT:
    begin
      TForm(Owner).Close;
    end;
  end;
end;

procedure TDashBoard.DoTimer(Sender: TObject);
  procedure DoMouseMove;
  var
    LInput: TInput;
  begin
    LInput.Itype := INPUT_MOUSE;
    LInput.mi.dwFlags := MOUSEEVENTF_MOVE;
    LInput.mi.mouseData := 0;
    LInput.mi.dx := 0;
    LInput.mi.dy := 0;
    LInput.mi.time := 0;
    LInput.mi.dwExtraInfo := 0;
    SendInput(1, LInput, SizeOf(LInput));
  end;
begin
  Dec(FCount);
  DoCountDown;

  if (FCount = 0) then
  begin
    FTimer.Enabled := False;
    try
      DSiTrimWorkingSet;
      DoMouseMove;

      ForEach(
        procedure(AItem: TCustomMonitorItem)
        begin
          AItem.Execute;
        end
      );
      FCount := FInterval;
      DoCountDown;
    finally
      FTimer.Enabled := True;
    end;
  end;
end;

procedure TDashBoard.DrawLines;
var
  i: Integer;
begin
  Canvas.Brush.Color := clGrayText;
  Canvas.FillRect(Rect(0, 0, Width, Height));

  for i := 0 to FLinks.Count-1 do
    FLinks[i].Draw(Canvas);
end;

procedure TDashBoard.ForEach(AProc: TProc<TCustomMonitorItem>);
var
  i: Integer;
begin
  for i := 0 to ControlCount-1 do
    if (Controls[i] is TCustomMonitorItem) then
      AProc(TCustomMonitorItem(Controls[i]));
end;

function TDashBoard.GetInterval: Integer;
begin
  Result := FInterval;
end;

procedure TDashBoard.Loaded;
begin
  inherited;
end;

procedure TDashBoard.LoadFromFile;
var
  LData: TJSONObject;
  LItem: TControl;
//  LLink: TLinkItem;
  LPath: string;
//  LSource: TControl;
//  LTarget: TControl;
  i: Integer;
begin
  LPath := ExtractFilePath(ParamStr(0));
  LData := TJSONObject.Create;
  try
    LData.LoadFromFile(LPath + 'ServerInfo.json');

    for i := 0 to LData.A['items'].Count-1 do
    begin
      LItem := Self.FindChildControl(LData.A['items'].O[i].S['name']);
      if (LItem <> nil) then
      begin
        TCustomMonitorItem(LItem).FromJSON(LData.A['items'].O[i]);
        TCustomMonitorItem(LItem).OnDblClick := DoEdit;
      end;
    end;

    // TODO ��ũ����
{
    FLinks.Clear;
    for i := 0 to LData.A['links'].Count-1 do
    begin
      LSource := FindChildControl(LData.A['links'].O[i].S['source']);
      LTarget := FindChildControl(LData.A['links'].O[i].S['target']);
      if (LSource <> nil) and (LTarget <> nil) then
      begin
        LLink := FLinks.Add;
        LLink.Source := LSource;
        LLink.SourcePosition := TLinkPosition(LData.A['links'].O[i].I['sourceposition']);
        LLink.Target := LTarget;
        LLink.TargetPosition := TLinkPosition(LData.A['links'].O[i].I['targetposition']);
      end;
    end;
}
  finally
    LData.Free;
  end;
end;

procedure TDashBoard.Notification(AComponent: TComponent; Operation: TOperation);
var
  i: Integer;
begin
  inherited;

  if (Operation = opRemove) then
    for i := FLinks.Count-1 downto 0 do
      if (FLinks[i].Source = AComponent) or (FLinks[i].Target = AComponent) then
        FLinks.Delete(i);
end;

procedure TDashBoard.Paint;
begin
  DrawLines;
end;

procedure TDashBoard.SaveToFile;
var
  LData: TJSONObject;
  LItem: TJSONObject;
  LPath: string;
  i: Integer;
begin
  LPath := ExtractFilePath(ParamStr(0));
  LData := TJSONObject.Create;
  try
    LData.A['items'] := TJSONArray.Create;
    for i := 0 to ControlCount-1 do
    begin
      if Controls[i].InheritsFrom(TCustomMonitorItem) then
      begin
        LItem := LData.A['items'].AddObject;
        LItem.Assign(TCustomMonitorItem(Controls[i]).ToJSON);
      end;
    end;

    // TODO
{
    LData.A['links'] := TJSONArray.Create;
    for i := 0 to FLinks.Count-1 do
    begin
      if (FLinks[i].Source <> nil) and (FLinks[i].Target <> nil) then
      begin
        LItem := LData.A['links'].AddObject;
        LItem.S['source'] := FLinks[i].Source.Name;
        LItem.I['sourcepos'] := Ord(FLinks[i].SourcePosition);
        LItem.S['target'] := FLinks[i].Target.Name;
        LItem.I['targetpos'] := Ord(FLinks[i].TargetPosition);
      end;
    end;
 }
    LData.SaveToFile(LPath + 'ServerInfo.json', False);
  finally
    LData.Free;
  end;
end;

procedure TDashBoard.SetInterval(const Value: Integer);
begin
  FInterval := Value;
end;

procedure TDashBoard.Start;
begin
  ForEach(
    procedure(AItem: TCustomMonitorItem)
    begin
      AItem.Execute;
    end
  );

  FCount := FInterval;
  Timer.Enabled := True;
  if Assigned(FOnStart) then
    FOnStart(Self);
end;

procedure TDashBoard.Stop;
begin
  FTimer.Enabled := False;
  ForEach(
    procedure(AItem: TCustomMonitorItem)
    begin
      AItem.Chart.Clear;
      AItem.State := ssNone;
    end
  );
  if Assigned(FOnStop) then
    FOnStop(Self);
end;

{$ENDREGION}

end.
