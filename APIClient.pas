//-------------------------------------------------------------------------------------------------------
//
//  Unit   : SEHR.API.pas
//  Author : �ȿ���
//  Description
//    �Ѿ�� �Ƿ�� EHR API�� ȣ���ϱ� ���� Ŭ���̾�Ʈ ���
//
//  History
//    1.0.0.0   2020.08.19 ó�� �ۼ�
//
//-------------------------------------------------------------------------------------------------------

unit SEHR.APIClient;

interface

uses
  System.SysUtils,
  System.Classes,
  Vcl.Dialogs,
  IdHTTP,
  IdIOHandler,
  IdSSLOpenSSL,
  SEHR.JSONDataObjects;

type
  /// <summary>
  ///   ���� ȣ�� ���
  /// </summary>
  THTTPMethod = (
    /// <summary>
    ///   GET
    /// </summary>
    hmGet,
    /// <summary>
    ///   POST
    /// </summary>
    hmPost
  );

  IAPIService = interface
    ['{F28BC91C-CCF6-48B8-849E-F5373F76BA07}']
    function  GetMethod: THTTPMethod;
    function  GetQuery: string;
    function  GetRequest: TJSONObject;
    function  GetResponse: TJSONObject;
    function  GetResponseCode: Integer;
    function  GetResponseText: string;
    function  GetService: string;
    procedure SetMethod(const Value: THTTPMethod);
    procedure SetResponseCode(const Value: Integer);
    procedure SetResponseText(const Value: string);
    procedure SetService(const Value: string);

    property Method: THTTPMethod read GetMethod write SetMethod;
    property Query: string read GetQuery;
    property Request: TJSONObject read GetRequest;
    property Response: TJSONObject read GetResponse;
    property ResponseCode: Integer read GetResponseCode write SetResponseCode;
    property ResponseText: string read GetResponseText write SetResponseText;
    property Service: string read GetService write SetService;
  end;

  TAPIService = class(TInterfacedObject, IAPIService)
  private
    FMethod: THTTPMethod;
    FQuery: string;
    FRequest: TJSONObject;
    FResponse: TJSONObject;
    FResponseCode: Integer;
    FResponseText: string;
    FService: string;

    function  GetMethod: THTTPMethod;
    function  GetQuery: string;
    function  GetRequest: TJSONObject;
    function  GetResponse: TJSONObject;
    function  GetResponseCode: Integer;
    function  GetResponseText: string;
    function  GetService: string;
    procedure SetMethod(const Value: THTTPMethod);
    procedure SetResponseCode(const Value: Integer);
    procedure SetResponseText(const Value: string);
    procedure SetService(const Value: string);
  protected
  public
    constructor Create; overload;
    constructor Create(const AService: string; const AMethod: THTTPMethod = hmGet); overload;
    constructor Create(const AService: string; AArgs: array of const; const AMethod: THTTPMethod = hmGet); overload;
    destructor Destroy; override;

    /// <summary>
    ///   ���� ȣ�� ���
    /// </summary>
    property Method: THTTPMethod read GetMethod write SetMethod;
    /// <summary>
    ///   GET ������� ���񽺸� ȣ���� ��� �Ķ���� (�б� ����)
    /// </summary>
    property Query: string read GetQuery;
    /// <summary>
    ///   <para>
    ///     ��û�� ���� �����͸� �����ϴ� JSON ��ü.
    ///   </para>
    ///   <para>
    ///     GET ����� ���񽺴� �� ��ü�� QueryString ���� ��ȯ�ϸ�, POST ����� ��� JSON ���ڿ��� ������ �����Ѵ�
    ///   </para>
    /// </summary>
    property Request: TJSONObject read GetRequest;
    /// <summary>
    ///   ������ ������ �����ϴ� JSON ��ü
    /// </summary>
    property Response: TJSONObject read GetResponse;
    /// <summary>
    ///   ������ ���� �ڵ�
    /// </summary>
    property ResponseCode: Integer read GetResponseCode write SetResponseCode;
    /// <summary>
    ///   ������ ���� �޽���
    /// </summary>
    property ResponseText: string read GetResponseText write SetResponseText;
    /// <summary>
    ///   ȣ���ϰ��� �ϴ� ���񽺸�
    /// </summary>
    property Service: string read GetService write SetService;
  end;

  TAPIClient = class
  strict private
    const
      GET_TOKEN_FAIL = '��ū�� ���� �� �����ϴ�';

    type
      TToken = class
      private
        FAcceptDate: TDateTime;
        FAccessToken: string;
        FExpire: Integer;
        FGrantType: string;
      public
        constructor Create;

        /// <summary>
        ///   ������ ������ JSON ��ü�� ���� ���� ä���
        /// </summary>
        procedure From(AData: string);
        /// <summary>
        ///   <para>
        ///     ��ū�� ��ȿ���� üũ�Ѵ�.
        ///   </para>
        /// </summary>
        /// <returns>
        ///   ��ū�� ����Ǿ���, ��ȿ�ð��� ���� �־�� True�� �����Ѵ�
        /// </returns>
        function  IsValid: Boolean;

        /// <summary>
        ///   ��ū�� ����� �Ͻ�
        /// </summary>
        property AcceptDate: TDateTime read FAcceptDate;
        /// <summary>
        ///   ��ū
        /// </summary>
        property AccessToken: string read FAccessToken write FAccessToken;
        /// <summary>
        ///   Grant Ÿ��
        /// </summary>
        property GrantType: string read FGrantType;
        /// <summary>
        ///   ��ū�� ��ȿ �ð�
        /// </summary>
        property Expire: Integer read FExpire write FExpire;
      end;

  private
    FHttpClient: TIdHTTP;
    FToken: TToken;

    function  GetHttpClient: TIdHTTP;
    function  GetToken: TToken;
    function  RequestToken(ATokenURL: string; AAPIKey: string): Boolean;
  public
    constructor Create;
    destructor Destroy; override;

    /// <summary>
    ///   HTTP ���񽺸� ȣ���Ѵ�
    /// </summary>
    procedure SendRequest(AService: IAPIService; AURL: string; ATokenURL: string; AAPIKey: string);
    /// <summary>
    ///   Token ��ü
    /// </summary>
    property Token: TToken read GetToken;
  end;

implementation

uses
  System.DateUtils,
  System.NetEncoding;

{$REGION 'TAPIService'}

constructor TAPIService.Create(const AService: string; AArgs: array of const; const AMethod: THTTPMethod);
begin
  //FMethod := hmGet;
  FMethod := AMethod;
  FRequest := TJSONObject.Create;
  FResponse := TJSONObject.Create;
  FResponseCode := 200;
  FResponseText := '';
  if Length(AArgs) > 0 then
    FService := Format(AService, AArgs)
  else
    FService := AService;
end;

constructor TAPIService.Create(const AService: string; const AMethod: THTTPMethod);
begin
  Create(AService, [], AMethod);
end;

constructor TAPIService.Create;
begin
  Create('', [], hmGet);
end;

destructor TAPIService.Destroy;
begin
  FRequest.Free;
  FResponse.Free;

  inherited;
end;

function TAPIService.GetMethod: THTTPMethod;
begin
  Result := FMethod;
end;

function TAPIService.GetQuery: string;
begin
  Result := FQuery;
end;

function TAPIService.GetRequest: TJSONObject;
begin
  Result := FRequest;
end;

function TAPIService.GetResponse: TJSONObject;
begin
  Result := FResponse;
end;

function TAPIService.GetResponseCode: Integer;
begin
  Result := FResponseCode;
end;

function TAPIService.GetResponseText: string;
begin
  Result := FResponseText;
end;

function TAPIService.GetService: string;
begin
  Result := FService;
end;

procedure TAPIService.SetMethod(const Value: THTTPMethod);
begin
  FMethod := Value;
end;

procedure TAPIService.SetResponseCode(const Value: Integer);
begin
  FResponseCode := Value;
end;

procedure TAPIService.SetResponseText(const Value: string);
begin
  FResponseText := Value;
end;

procedure TAPIService.SetService(const Value: string);
begin
  FService := Value;
end;

{$ENDREGION}

{$REGION 'TAPIClient.TToken'}

constructor TAPIClient.TToken.Create;
begin
  FAccessToken := '';
  FExpire := 0;
  FGrantType := 'grant_type=client_credentials';
end;

procedure TAPIClient.TToken.From(AData: string);
var
  LData: TJSONObject;
begin
  LData := TJSONObject.Parse(AData) as TJSONObject;
  try
    FAcceptDate := Now();
    FAccessToken := LData.S['access_token'];
    FExpire := LData.I['expires_in'];
  finally
    LData.Free;
  end;
end;

function TAPIClient.TToken.IsValid: Boolean;
begin
  Result := (FAccessToken <> EmptyStr) and (SecondsBetween(FAcceptDate, Now) < FExpire);
end;

{$ENDREGION}

{$REGION 'TAPIClient'}

constructor TAPIClient.Create;
begin
  FToken := TToken.Create;
end;

destructor TAPIClient.Destroy;
begin
  FToken.Free;

  if Assigned(FHttpClient) then
    FreeAndNil(FHttpClient);

  inherited;
end;

function TAPIClient.GetHttpClient: TIdHTTP;
var
  LSSLHandler: TIdSSLIOHandlerSocketOpenSSL;
begin
  if not Assigned(FHttpClient) then
  begin
    FHttpClient := TIdHTTP.Create(nil);

    FHttpClient.AllowCookies := True;
    FHttpClient.HTTPOptions := [hoKeepOrigProtocol];
    FHttpClient.ProtocolVersion := pv1_1;

    FHttpClient.Response.ContentType := 'application/json';
    FHttpClient.Response.CharSet := 'utf-8';

    LSSLHandler := TIdSSLIOHandlerSocketOpenSSL.Create(FHttpClient);
    LSSLHandler.SSLOptions.VerifyMode := [];
    LSSLHandler.SSLOptions.VerifyDepth := 0;
    LSSLHandler.SSLOptions.Method := sslvTLSv1_2;
    LSSLHandler.SSLOptions.Mode := sslmUnassigned;

    FHttpClient.IOHandler := LSSLHandler;
  end;

  Result := FHttpClient;
end;

function TAPIClient.GetToken: TToken;
begin
  Result := FToken;
end;

function TAPIClient.RequestToken(ATokenURL: string; AAPIKey: string): Boolean;
var
  LHttpClient: TIdHTTP;
  LURL: string;
  LRequest: TStringStream;
  LResponse: TStringStream;
begin
  Result := False;

  // ��ū�� ����ϱ� ���� �ּ�
  LURL := ATokenURL + '/token';

//  ShowMessage('Token ȣ�� �ּ� : ' + LURL);

  LHttpClient := GetHttpClient;
  LHttpClient.Request.CustomHeaders.Clear;
  LHttpClient.Request.CustomHeaders.Add('Authorization: Basic ' + AAPIKey);
  LHttpClient.Request.ContentType := 'application/x-www-form-urlencoded';
  LHttpClient.Request.CharSet := 'utf-8';

  // ��û �� ���� ��Ʈ��
  LRequest := TStringStream.Create(Token.GrantType, TEncoding.UTF8);
  LResponse := TStringStream.Create('', TEncoding.UTF8);

  try
    LHttpClient.Post(LURL, LRequest, LResponse);
    if (LHttpClient.ResponseCode = 200) then
    begin
      FToken.From(LResponse.DataString);

      // ����� ��ū ������ �����Ѵ�
      LHttpClient.Request.CustomHeaders.Clear;
      LHttpClient.Request.CustomHeaders.Add('Authorization: Bearer ' + FToken.AccessToken);

      Result := True;
    end;
  finally
    FreeAndNil(LRequest);
    FreeAndNil(LResponse);
  end;
end;

procedure TAPIClient.SendRequest(AService: IAPIService; AURL: string; ATokenURL: string; AAPIKey: string);
var
  LHttpClient: TIdHTTP;
  LResponse: TStringStream;
begin
  if not Token.IsValid then
  begin
    if not RequestToken(ATokenURL, AAPIKey) then
      raise Exception.Create(GET_TOKEN_FAIL);
  end;

  LResponse := TStringStream.Create('', TEncoding.UTF8);
  try
    LHttpClient := GetHTTPClient;
    LHttpClient.Request.ContentType := 'application/x-www-form-urlencoded';
    LHttpClient.Request.CharSet := 'utf-8';

    LHttpClient.Get(AURL + AService.Query, LResponse);

    if LHttpClient.ResponseCode = 401 then
    begin
      // ��ū ������ ���� ���� ���
      if not RequestToken(ATokenURL, AAPIKey) then
        raise Exception.Create(GET_TOKEN_FAIL);

        LHttpClient.Get(AURL + AService.Query, LResponse);
    end;

    AService.ResponseCode := LHttpClient.ResponseCode;

    if (LHttpClient.ResponseCode = 200) then
    begin
      LResponse.Position := 0;
      AService.Response.LoadFromStream(LResponse);
    end
    else
      AService.ResponseText := LHttpClient.ResponseText;
  finally
    FreeAndNil(LResponse);
  end;
end;

end.
