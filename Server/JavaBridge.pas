unit JavaBridge;

interface

uses
  SysUtils, Classes,
  JNI, JNIWrapper, JavaRuntime,
  AdvObjects, AdvJson,
  FHIRBase, FHIRResources, FHIRParser, FHIRUtilities;

type
  TJByteArray = TDshortintArray; //array of jbyte;

  TJavaLibraryWrapper = class (TAdvObject)
  private
    Jvm : TJavaRuntime;
    JLibraryClass : TJavaClass;
    JLibrary : TJavaObject;
    JThrowableClass : TJavaClass;
    JStringClass : TJavaClass;
    JGetMessage : TJavaMethod;
    JInit : TJavaMethod;
    JTxConnect : TJavaMethod;
    JStatus : TJavaMethod;
    JSeeResource : TJavaMethod;
    JDropResource : TJavaMethod;
    JValidate : TJavaMethod;
    JConvert : TJavaMethod;
    JUnConvert : TJavaMethod;
    procedure checkException;
    function convertToJByteArray(b : TBytes) : TJByteArray;
    function convertFromJByteArray(b : TJByteArray) : TBytes;
  public
    Constructor Create(jarPath : String); virtual;
    Destructor Destroy; override;

    procedure init(packPath : String);
    procedure txConnect(txServer : String);
    function status : TJsonObject;

    procedure seeResource(r : TFHIRResource);
    procedure dropResource(type_, id, url, bver : String);

    function validateResource(location : String; source : TBytes; format : String) : TFHIROperationOutcome;

    function convertResource(source : TBytes; fmt, version : String) : TBytes;
    function unConvertResource(source : TBytes; fmt, version : String) : TBytes;
  end;

implementation

{ TJavaLibraryWrapper }

procedure TJavaLibraryWrapper.checkException;
var
  j : jthrowable;
  o : TJavaObject;
  s : String;
begin
  j := Jvm.GetVM.checkException;
  if j <> nil then
  begin
    o := TJavaObject.CreateWithHandle(JThrowableClass, j);
    try
      s := o.toString;
    finally
      o.Free;
    end;
    Jvm.GetVM.clearException;
    raise Exception.Create(s);
  end;
end;

function TJavaLibraryWrapper.convertResource(source: TBytes; fmt, version: String): TBytes;
var
  p : TJavaParams;
  v : jvalue;
begin
  p := TJavaParams.Create;
  try
    p.addByteArray(convertToJByteArray(source));
    p.addString(fmt);
    p.addString(version);
    v := JConvert.Call(p, JLibrary);
  finally
    p.Free;
  end;
  checkException;
  result := convertFromJByteArray(JbyteArrayToDshortintArray(v.l));
end;

constructor TJavaLibraryWrapper.Create(jarPath: String);
begin
  inherited Create;
  Jvm := TJavaRuntime.GetDefault;
  Jvm.addToClasspath(jarPath); // 'C:\work\org.hl7.fhir\build\publish\org.hl7.fhir.validator.jar';
  JThrowableClass := TJavaClass.Create('java.lang.Throwable');
  JStringClass := TJavaClass.Create('java.lang.String');
  {$IFDEF FHIR4}
  JLibraryClass := TJavaClass.Create('org.hl7.fhir.r4.validation.NativeHostServices');
  checkException;
  {$ENDIF}
  {$IFDEF FHIR3}
  JLibraryClass := TJavaClass.Create('org.hl7.fhir.dstu3.validation.NativeHostServices');
  {$ENDIF}
  {$IFDEF FHIR2}
  raise Exception.Create('There is no Java bridge for DSTU2');
  {$ENDIF}

  JLibrary := JLibraryClass.Instantiate(nil);
  JGetMessage := TJavaMethod.Create(JThrowableClass, 'getMessage', nonstatic, AString, []);
  JInit := TJavaMethod.Create(JLibraryClass, 'init', nonstatic, Void, [AString]);
  JTxConnect := TJavaMethod.Create(JLibraryClass, 'connectToTxSvc', nonstatic, Void, [AString]);
  JStatus := TJavaMethod.Create(JLibraryClass, 'status', nonstatic, AString, []);
  JSeeResource := TJavaMethod.Create(JLibraryClass, 'seeResource', nonstatic, Void, [AByteArray]);
  JDropResource := TJavaMethod.Create(JLibraryClass, 'dropResource', nonstatic, Void, [AString, AString, AString, AString]);
  JValidate := TJavaMethod.Create(JLibraryClass, 'validateResource', nonstatic, AByteArray, [AString, AByteArray, AString]);
  JConvert := TJavaMethod.Create(JLibraryClass, 'convertResource', nonstatic, AByteArray, [AByteArray, AString, AString]);
  JUnConvert := TJavaMethod.Create(JLibraryClass, 'unConvertResource', nonstatic, AByteArray, [AByteArray, AString, AString]);
end;

destructor TJavaLibraryWrapper.Destroy;
begin
  JUnConvert.Free;
  JConvert.Free;
  JValidate.Free;
  JDropResource.Free;
  JStringClass.Free;
  JStatus.Free;
  JSeeResource.Free;
  JGetMessage.Free;
  JThrowableClass.Free;
  JTxConnect.Free;
  JInit.Free;
  JLibrary.Free;
  JLibraryClass.Free;
  Jvm.Free;
  inherited;
end;

procedure TJavaLibraryWrapper.dropResource(type_, id, url, bver: String);
var
  p : TJavaParams;
begin
  p := TJavaParams.Create;
  try
    p.addString(type_);
    p.addString(id);
    p.addString(url);
    p.addString(bver);
    JDropResource.Call(p, JLibrary);
  finally
    p.Free;
  end;
  checkException;
end;

procedure TJavaLibraryWrapper.init(packPath: String);
var
  p : TJavaParams;
  r : jvalue;
begin
  p := TJavaParams.Create;
  try
    p.AddString(packPath);
    r := JInit.Call(p, JLibrary);
  finally
    p.Free;
  end;
  checkException;
end;

procedure TJavaLibraryWrapper.txConnect(txServer: String);
var
  p : TJavaParams;
  r : jvalue;
begin
  p := TJavaParams.Create;
  try
    p.AddString(txServer);
    r := JTxConnect.Call(p, JLibrary);
  finally
    p.Free;
  end;
  checkException;
end;

function TJavaLibraryWrapper.status: TJsonObject;
var
  v : jvalue;
  o : TJavaObject;
begin
  v := JStatus.Call(nil, JLibrary);
  o := TJavaObject.CreateWithHandle(JStringClass, v.l);
  try
    result := TJSONParser.Parse(o.toString);
  finally
    o.Free;
  end;
end;

function TJavaLibraryWrapper.unConvertResource(source: TBytes; fmt, version: String): TBytes;
var
  p : TJavaParams;
  v : jvalue;
begin
  p := TJavaParams.Create;
  try
    p.addByteArray(convertToJByteArray(source));
    p.addString(fmt);
    p.addString(version);
    v := JUnConvert.Call(p, JLibrary);
  finally
    p.Free;
  end;
  checkException;
  result := convertFromJByteArray(JbyteArrayToDshortintArray(v.l));
end;

function TJavaLibraryWrapper.validateResource(location: String; source: TBytes; format: String): TFHIROperationOutcome;
var
  p : TJavaParams;
  b : TBytes;
  jb : TJByteArray;
  v : jvalue;
begin
  p := TJavaParams.Create;
  try
    p.addString(location);
    p.addByteArray(convertToJByteArray(source));
    p.addString(format);
    v := JValidate.Call(p, JLibrary);
  finally
    p.Free;
  end;
  checkException;
  jb := JbyteArrayToDshortintArray(v.l);
  b := convertFromJByteArray(jb);
  result := bytesToResource(b) as TFHIROperationOutcome;
end;

procedure TJavaLibraryWrapper.seeResource(r: TFHIRResource);
var
  xml : TFHIRXmlComposer;
  s : TBytesStream;
  p : TJavaParams;
  b : TBytes;
  jb : TJByteArray;
begin
  s := TBytesStream.Create();
  try
    xml := TFHIRXmlComposer.Create(nil, OutputStyleNormal, 'en');
    try
      xml.Compose(s, r);
    finally
      xml.Free;
    end;
    b := s.Bytes;
    setLength(b, s.Size);
    jb := convertToJByteArray(b);
    p := TJavaParams.Create;
    try
      p.addByteArray(jb);
      JSeeResource.Call(p, JLibrary);
    finally
      p.Free;
    end;
    checkException;
  finally
    s.Free;
  end;
end;

//function TJavaLibraryWrapper.unConvertResource(r: TBytes;
//  src: String): TFHIRResource;
//begin
//
//end;
//
//function TJavaLibraryWrapper.validateResource(r: TFHIRResource;
//  version: String): TFHIROperationOutcome;
//begin
//
//end;
//
//function TJavaLibraryWrapper.convertResource(r: TFHIRResource;
//  dst: String): TBytes;
//begin
//
//end;
//
//
//procedure TJavaLibraryWrapper.dropResource(r: TFHIRResource);
//begin
//
//end;


{$R-}

function TJavaLibraryWrapper.convertToJByteArray(b: TBytes): TJByteArray;
var
  i : integer;
begin
  SetLength(result, length(b));
  for i := 0 to length(b) - 1 do
    result[i] := b[i];
end;

function TJavaLibraryWrapper.convertFromJByteArray(b: TJByteArray): TBytes;
var
  i : integer;
begin
  SetLength(result, length(b));
  for i := 0 to length(b) - 1 do
    result[i] := b[i];
end;

end.