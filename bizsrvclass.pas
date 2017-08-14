unit bizsrvclass;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, DB,fgl,MemDataSet,DBAccess,Variants,Uni,strutils,PostgreSQLUniProvider,
  InterBaseUniProvider, CRAccess,bizstream,fpjson, jsonparser,IdHTTP;

const
  app_wqbl: integer=10;
  app_dlsc: integer=2;
  app_ecd: integer=5;
  app_nyj: integer=6;
  app_dwsj: integer=7;
  app_dlsy: integer=8;
  app_tzw: integer=9; //taozhiwang

  BLOCKSIZE: integer=1024*64;

  maxlocaldbsize: int64=1048576*20;
  maxtablespace: integer=128;
  maxsendfileblock: integer=1024*31;

type
  TISMap = specialize TFPGMap<integer,string>;
  TBizLang = (langZh, langTr, langEn, langFr, langDu, langJp, langKr, langSp, langRu);
  TBizFileType = (ftUTF8, ftUnicode, ftAnsi);
	TBizBytes = record
  	Len: integer;
    Data: PChar;
  end;

  PTBizBytes = ^TBizBytes;
  TBizProcessProc = procedure(filename: pchar); cdecl;
  { TBizTextFile }

  TBizTextFile = class(TObject)
  private
    ffile: tfilestream;
    fbuf: array[1..4096] of byte;
    fbufpos: integer;
    fbuflen: integer;
    fopened: boolean;
    feof: boolean;
    flastblock: boolean;
    ffiletype: tbizfiletype;
  public
    constructor create;
    destructor destroy; override;
    procedure createnewfile(fname: string; ftype: TBizFileType=ftutf8);
    procedure openexistfile(fname: string; readonly: boolean=false; ftype: TBizFileType=ftutf8);
    procedure close;
    property eof: boolean read feof;
    function readln: string;
    procedure writeln(s: string; cronly: boolean=true);
    procedure write(s: string);
    procedure appendln(s: string; cronly: Boolean=true);
    procedure writestring(s: string);
    property filetype: tbizfiletype read ffiletype;
  end;

  TBizLock = class(TObject)
  private
    FLockName: string;
    fd: integer;
  public
    constructor Create(LockName: string);
    destructor Destroy; override;
  end;

  TBizSession=class;
  TServiceProc = function(session: TBizSession; appid: integer; const path,query,param: string; var redirecturl: string; var retlen: integer): string;
  TServiceEntry = record
    svcid: integer;
    serviceproc: TServiceProc;
    desc: string;
    isbinary: boolean;
  end;

  PServiceEntry = ^ TServiceEntry;
  TPackageEntry = record
    pkgid: integer;
    service: array[1..512] of TServiceEntry;
    svccount: integer;
    desc: string;
    isok: integer;
  end;
  PPackageEntry = ^ TPackageEntry;

  TtmpPackageEntry = record
    pkgid: integer;
    service: PServiceEntry;
    svccount: integer;
    desc: string;
    isok: integer;
  end;
  PtmpPackageEntry = ^ TtmpPackageEntry;

  TBizLoginState = record
    servername: array[1..16] of char;
    appid: integer;
    appname: array[1..64] of char;
    lang: integer;
    compid: integer;
    uuid: array[1..64] of char;
    islogin: integer; //
    logintype: integer; // 0-notlogin 1-wx login 2- wx scan 3-password
    uid: integer;
    wxid: array[1..64] of char;
    username: array[1..64] of char;
    singlevisit: integer;
    pkgid: integer;
    svcid: integer;
    lastaccess: TDatetime;
    remoteaddr: array[1..64] of char;
    remotedevice: array[1..64] of char;
    vars: array[1..512] of char;
  end;
  PBizLoginState = ^ TBizLoginState;

  TBizServerParam = record
    servername: array[1..16] of char;
    tmppath: array[1..64] of char;
    stddb: array[1..64] of char;
    dbserver: array[1..64] of char;
    dbport: integer;
    dbusername: array[1..64] of char;
    dbpassword: array[1..128] of char;
    dbname: array[1..16] of char;
    appservername: array[1..32,1..32] of char;
    appname: array[1..32,1..64] of char;
    appdb: array[1..32,1..16] of char;
    releasefilepath: array[1..32,1..64] of char;
    wxappid: array[1..32,1..64] of char;
    wxsecret: array[1..32,1..64] of char;
  end;

  PBizServerParam = ^ TBizServerParam;

  TBizwxapp = record
    appid: integer;
    appname: string;
    wxappid: string;
    wxsecret: string;
  end;

  { TBizLocalTable }

  TBizLocalTable = class(TUniQuery)
  private
    fsession: tbizsession;
    flocaltable: tunitable;
    forder: string;
    ftablename: string;
    flocfieldlist: string;
  public
    fcreatefromsession: boolean;
    constructor create(aowner: tcomponent); override;
    destructor destroy; override;
    procedure empty;
    property db: tunitable read flocaltable;
    procedure createlocaltable(order: string; isprimary: boolean=false);
    procedure refresh;
    function savetofile: string;
  end;

  { TBizMessage }

  TBizMessage = class(Exception)
  private
    FSysID: integer; // $fff
    Fmsgid: Integer;  // $fff
    FParam1: string;
    FParam2: string;
    FParam3: string;
    flang: tbizlang;
  public
    constructor Create(lang: tbizlang; SysID, MsgID: integer; const Param1,
      Param2, Param3: string); overload;
  	constructor Create(MsgID: integer; const Param1: string=''; const Param2: string=''; const Param3: string='');  overload;
    destructor Destroy; override;
    property SysID: integer read FSysID write fsysid;
    property msgid: integer read fmsgid write fmsgid;
    property param1: string read fparam1 write fparam1;
    property param2: string read fparam2 write fparam2;
    property param3: string read fparam3 write fparam3;
    property lang: tbizlang read flang;
    class function getmsg(mylang: tbizlang; mysysid,mymsgid: integer; const myParam1: string=''; const myParam2: string=''; const myParam3: string=''): string;
    class procedure raiseerror(mylang: tbizlang; mysysid,mymsgid: integer; const myParam1: string=''; const myParam2: string=''; const myParam3: string='');
  end;

  TBizHTML = class(TObject)
  private
    FContent: string;
    findent: integer;
    flang: tbizlang;
  public
    procedure clear;
    procedure WriteHTML;
    procedure CloseHTML;
    procedure WriteTABLE(const attribute: string='');
    procedure CloseTABLE;
    procedure WriteTR(const attribute: string='');
    procedure CloseTR;
    procedure WriteTD(const attribute: string='');
    procedure CloseTD;
    procedure WriteFORM(const attribute: string);
    procedure CloseFORM;
    procedure WriteDIV(const attribute: string);
    procedure CloseDIV;
    procedure AppendB(const val: string; const attribute: string=''; needreplace: boolean=false);
    procedure AppendP(const val: string; const attribute: string=''; needreplace: boolean=false);
    procedure AppendSPAN(const val: string; const attribute: string=''; needreplace: boolean=false);
    procedure AppendFONT(const val: string; const attribute: string=''; needreplace: boolean=false);
    procedure AppendA(const href: string; const val: string=''; const attribute: string=''; needreplace: boolean=false);
    procedure WriteSCRIPT;
    procedure CloseSCRIPT;
    procedure WriteSTYLE;
    procedure CloseSTYLE;
    procedure WriteHEAD;
    procedure CloseHEAD;
    procedure WriteBODY(const attribute: string='');
    procedure CloseBODY;
    procedure AppendLine(const Line: string; autoindent: boolean=true; needreplace: boolean=false);
    procedure append(const str: string; needreplace: boolean=false);
    procedure AppendCHARSET(const charset: string='');
    procedure AppendScriptFile(const srcfile: string);
    procedure AppendLinkCSSFile(const srcfile: string);
    procedure AppendTITLE(const title: string; needreplace: boolean=false);
    property content: string read fcontent;
    property lang: tbizlang read flang write flang;
    function replace(const val: string): string;
    function getmsg(const msg: string): string;
    constructor create(l: tbizlang=langzh);
    procedure AppendSelect(const attribute,valkey,selectedkey: string;needreplace: boolean=false);
    procedure WriteUL(const attribute: string='');
    procedure CloseUL;
    procedure writeLI(const attribute: string='');
    procedure CloseLI;
    procedure AppendSTRONG(const val: string; const attribute: string=''; needreplace: boolean=false);
    procedure AppendH2(const val: string; const attribute: string=''; needreplace: boolean=false);
  end;

  { LDatabase }

  TBizDatabase = class(TUniConnection)
  end;

  { LQuery }

  { TBizQuery }

  TBizQuery = class(TUniQuery)
  private
    FFieldList: string;
    FTableList: string;
    FCondition: string;
    FOrder: string;
    FGroup: string;
    FHaving: string;
    FLimit: integer;
    FOffset: integer;
    FSession: TBizSession;

    function getsqlstmt: string;
    procedure SetFieldList(const Value: string);

  public
    constructor create(aowner: tcomponent); override;
    destructor destroy; override;
    property FieldList: string read FFieldList write SetFieldList;
    property TableList: string read FTableList write FTableList;
    property Condition: string read FCondition write FCondition;
    property limit: integer read flimit write flimit;
    property offset: integer read foffset write foffset;
    property Order: string read FOrder write FOrder;
    property Group: string read FGroup write FGroup;
    property Having: string read FHaving write FHaving;
    property sqlstmt: string read getsqlstmt;
    procedure Duplicate(LocTable: TBizLocalTable; const primary: string='');
    procedure open(const sql1: string='');
    function duplicatetofile: string;
    function savetofile: string;
  end;

  { TBizSession }

  TBizSession = class
  private
    FLoginState: PBizLoginState;
    fglobalservername: string;
    fservername: string;
    ftmppath: string;
    fappid: integer;
    fstrings: tstringlist;
    fstrings1: tstringlist;
    fstrings2: tstringlist;
    fstrings3: tstringlist;
    fdatabase: tbizdatabase;
    fquerylist: tlist;
    flocaltablelist: tlist;
    fcompid: integer;
    fsubcompid: integer;
    fremoteip: string;
    fremotemac: string;
    fhtml: tbizhtml;
    flocaldb: tuniconnection;
    freadstream: tbizstream;
    fwritestream: tbizstream;
    fusername: string;
    fcompname: string;
    fareaid: integer;
    fareastr: string;
    fstartcompid: integer;
    fneedexit: boolean;
    fremoteaddr: string;
    fremotedevice: string;

    function getcomptype: string;
    function gethtml: tbizhtml;
    function getintransaction: boolean;
    function getislogin: boolean;
    function getlang: tbizlang;
    function getlangid: string;
    function getlangstr: string;
    function getprefix: string;
    function getquery1: tbizquery;
    function getquery2: tbizquery;
    function getquery3: tbizquery;
    function getlocquery: tbizquery;
    function getreasefilepath(ind: integer): string;
    function getstrings: tstringlist;
    function getstrings1: tstringlist;
    function getstrings2: tstringlist;
    function getstrings3: tstringlist;
    function GetUID: integer;
    function getusername: string;
    function getuuid: string;
    function getvariables(varname: string): string;
    function getwxaccesstoken: string;
    function getwxappid: string;
    function getwxid: string;
    function getwxjsticket: string;
    function getwxsecret: string;
    procedure setusername(AValue: string);
    procedure setvariables(varname: string; AValue: string);
  public
    property loginstate: PBizLoginState read FLoginState;
    property strings: tstringlist read getstrings;
    property strings1: tstringlist read getstrings1;
    property strings2: tstringlist read getstrings2;
    property strings3: tstringlist read getstrings3;
    property servername: string read fservername write fservername;
    property tmppath: string read ftmppath write ftmppath;
    property appid: integer read fappid write fappid;
    property wxaccesstoken: string read getwxaccesstoken;
    property wxjsticket: string read getwxjsticket;
    property wxappid: string read getwxappid;
    property wxsecret: string read getwxsecret;
    property intransaction: boolean read getintransaction;
    property prefix: string read getprefix;
    property compid: integer read fcompid write fcompid;
    property subcompid: integer read fsubcompid write fsubcompid;
    property remoteip: string read fremoteip write fremoteip;
    property remotemac: string read fremotemac write fremotemac;
    property lang: tbizlang read getlang;
    property langstr: string read getlangstr;
    property langid: string read getlangid;
    property html: tbizhtml read gethtml;
    property wxid: string read getwxid;
    property uid: integer read getuid;
    property username: string read getusername write setusername;
    property query1: tbizquery read getquery1;
    property query2: tbizquery read getquery2;
    property query3: tbizquery read getquery3;
    property query: tbizquery read getlocquery;

    constructor Create;
    destructor destroy; override;

    procedure starttransaction;
    procedure commit;
    procedure rollback;

    function getglobalsequence(seqid: integer; update: boolean=true): integer;
    procedure setweblogin(const strwxid,strusername: string; nuid: integer; const loclang: string);
    function getsequence(seqid: integer; update: boolean=true): integer;
    procedure Insert(const TableName, FieldList:string; const Args: array of const); overload;
    procedure Insert(DataSet: TDataSet; const TableName, FieldList:string; AllRecord: boolean=False); overload;
    procedure Update(const TableName, FieldList, Condition: string; const Args: array of const); overload;
    procedure Update(DataSet: TDataSet; const TableName, FieldList, KeyFields: string; UpdateAll: boolean=False); overload;
    procedure Update(DataSet: TDataSet; const LocateFields: string; const LocateValue: array of const; const TableName, FieldList: string); overload;
    procedure Delete(const TableName, Condition: string);
    procedure initsession(mystate: PBizLoginState);
    procedure exitsession;
    function getdatabase: tbizdatabase;
    function getquery: tbizquery;
    function getlocaltable: tbizlocaltable;
    procedure execsql(const sql: string);
    function getcomptable(const tablename: string): string;
    function getdatatablespace: string;
    function getindextablespace: string;

    procedure writeint(i: integer);
    procedure writeint64(i: int64);
    procedure writestring(const val: string);
    procedure writechar(b: char);
    procedure writebuffer(p: pchar; len: integer);
    procedure writelenbuffer(p: pchar; len: integer);
    function writebuffer(stream: tstream; len: integer): integer;
    procedure writedatetime(dt: tdatetime);
    function readint: integer;
    function readint64: integer;
    function readstring: string;
    function readchar: char;
    function readbuffer(p: pchar; len: integer): integer;
    function readlenbuffer(p: pchar; len: integer): integer;
    function readdatetime: tdatetime;

    property readstream: tbizstream read freadstream;
    property writestream: tbizstream read fwritestream;
    property variables[varname: string]: string read getvariables write setvariables;
    property islogin: boolean read getislogin;
    procedure login(l: tbizlang; cid: integer; const uname,pwd: string; var needverify: integer);
    property comptype: string read getcomptype;
    property compname: string read fcompname write fcompname;
    property globalservername: string read fglobalservername write fglobalservername;
    property areaid: integer read fareaid write fareaid;
    property areastr: string read fareastr write fareastr;
    function gettime(loctm: tdatetime): tdatetime;
    property uuid: string read getuuid;
    property startcompid: integer read fstartcompid;
    property releasefilepath[ind: integer]: string read getreasefilepath;
    function regetwxtoken: string;
    property remotedevice: string read fremotedevice;
    property remoteaddr: string read fremoteaddr;
  end;

  { TBizJsonReader }
  TBizJsonValue=class;
  TBizJsonReader = class
  private
    FReader: pointer;
    FValueObject: TBizJsonValue;
    FValue: pointer;
    FValueList: TList;
  public
    constructor create;
    destructor destroy; override;
    procedure parse(const jsonstr: string);
    function get(const jname: string): string;
    function get(index: integer): string; overload;
    function getvalue(const jname: string): tbizjsonvalue;
    function count: integer;
    function getvalue(index: integer): tbizjsonvalue; overload;
  end;

  { TBizJsonValue }

  TBizJsonValue = class
  private
    FValue: pointer;
    FReader: TBizJsonReader;
  public
    function get(const jname: string): string;
    function get(index: integer): string; overload;
    function getvalue(const jname: string): TBizJsonValue;
    function count: integer;
    function getvalue(index: integer): tbizjsonvalue; overload;
  end;

  { TBizSOLib }

  TBizSOLib = class
  private
    ffilename: string;
    fhandle: pointer;
  public
    constructor create;
    destructor destroy; override;
    function getprocbyname(const procname: string): pointer;
    procedure loadlib(const filename: string);

    property filename: string read ffilename;
    property handle: pointer read fhandle;
  end;

procedure initmsg;

var
  mysession: TBizsession=nil;
  databaselist: array[1..32] of TBizdatabase;
  querylist: array[1..32,0..3] of TBizQuery;
  packagelist: array[0..100] of TPackageEntry;
  retresult: string='';
  reterrcode: integer=0;
  reterror: string='';
  redirecturl: string='';
  serverparam: PBizServerParam;
  tmpfilename: string;

  zhmsgmap: TISMap=nil;
  Trmsgmap: TISMap=nil;
  Enmsgmap: TISMap=nil;
  Frmsgmap: TISMap=nil;
  Dumsgmap: TISMap=nil;
  Jpmsgmap: TISMap=nil;
  Krmsgmap: TISMap=nil;
  Spmsgmap: TISMap=nil;
  Rumsgmap: TISMap=nil;
  commmsgmap: TISMap=nil;

implementation
uses bizutils;
var
  wxapps: array[1..12] of TBizwxapp = (
    (appid:1;appname:'';wxappid:'';wxsecret:'')
    ,(appid:2;appname:'';wxappid:'';wxsecret:'')
    ,(appid:3;appname:'NMGDLSC';wxappid:'wx7389047e849f804f';wxsecret:'ddebf0f67fe933d835ff4a8db3271428')
    ,(appid:4;appname:'';wxappid:'';wxsecret:'')
    ,(appid:5;appname:'';wxappid:'';wxsecret:'')
    ,(appid:6;appname:'SCXX';wxappid:'wx65b1b7c78e7ac389';wxsecret:'27d1e123aa6435930509b426b08c8079')
    ,(appid:7;appname:'';wxappid:'';wxsecret:'')
    ,(appid:8;appname:'';wxappid:'';wxsecret:'')
    ,(appid:9;appname:'';wxappid:'';wxsecret:'')
    ,(appid:10;appname:'WQBL';wxappid:'wxd5bf96058d2c7343';wxsecret:'7f3972df010306b5572e33251a6505a0')
    ,(appid:11;appname:'NMGDKZX';wxappid:'wxec4d939be7af14fb';wxsecret:'581d89177018341d906de30088b368ec')
    ,(appid:12;appname:'XSCS';wxappid:'wx97529f4e42439100';wxsecret:'b35ed56409716807c07c982a7cbd8d2d')
  );

{ TBizSOLib }

function locloadlib(p: pchar): pointer; cdecl; external 'bizutils' name 'bizloadlib';
procedure loccloselib(h: pointer); cdecl; external 'bizutils' name 'bizcloselib';
function locgetprocbyname(h: pointer; procname: pchar): pointer; cdecl; external 'bizutils' name 'bizgetprocbyname';
constructor TBizSOLib.create;
begin
  inherited;
  ffilename := '';
  fhandle := nil;
end;

destructor TBizSOLib.destroy;
begin
  if fhandle<>nil then begin
    loccloselib(fhandle);
    fhandle := nil;
  end;

  inherited destroy;
end;

function TBizSOLib.getprocbyname(const procname: string): pointer;
begin
  result := locgetprocbyname(fhandle,pchar(procname));
end;


procedure TBizSOLib.loadlib(const filename: string);
begin
  if fhandle<>nil then begin
    loccloselib(fhandle);
    fhandle := nil;
  end;

  fhandle := locloadlib(pchar(filename));
  if fhandle=nil then raise exception.create('load '+filename+' error!');
end;

{ TBizJsonReader }

constructor TBizJsonReader.create;
begin
  inherited create;
  FValueList := TList.create;
  freader := biznewjsonreader;
end;

destructor TBizJsonReader.destroy;
begin
  inherited destroy;
end;

procedure TBizJsonReader.parse(const jsonstr: string);
begin
  fvalue := bizjsonparse(freader, jsonstr);
  FValueObject := TBizJsonValue.create;
  fvalueobject.fvalue := fvalue;
  fvalueobject.freader := self;
  fvaluelist.add(fvalueobject);
end;

function TBizJsonReader.get(const jname: string): string;
begin
  result := FValueObject.get(jname);
end;

function TBizJsonReader.get(index: integer): string;
begin
  result := FValueObject.get(index);
end;

function TBizJsonReader.getvalue(const jname: string): tbizjsonvalue;
var
  v: pointer;
  val: tbizjsonvalue;
begin
  v := bizgetjsonvalue(fvalue,jname);
  fvalueobject := TBizJsonValue.create;
  fvalueobject.fvalue := v;
  fvalueobject.freader := self;
  fvaluelist.add(fvalueobject);
  result := fvalueobject;
end;

function TBizJsonReader.count: integer;
begin
  result := bizgetjsonvaluesize(fvalue);
end;

function TBizJsonReader.getvalue(index: integer): tbizjsonvalue;
begin
  fvalueobject.getvalue(index);
end;

{ TBizJsonValue }

function TBizJsonValue.get(const jname: string): string;
begin
  result := bizgetjsonvaluestring(fvalue,jname);
end;

function TBizJsonValue.get(index: integer): string;
begin
  result := bizgetjsonvaluestringbyindex(fvalue,index);
end;

function TBizJsonValue.getvalue(const jname: string): TBizJsonValue;
var
  v: pointer;
  val: tbizjsonvalue;
begin
  v := bizgetjsonvalue(fvalue,jname);
  val := TBizJsonValue.create;
  val.fvalue := v;
  val.freader := freader;
  freader.fvaluelist.add(val);
  result := val;
end;

function TBizJsonValue.count: integer;
begin
  result := bizgetjsonvaluesize(fvalue);
end;

function TBizJsonValue.getvalue(index: integer): tbizjsonvalue;
var
  v: pointer;
  val: tbizjsonvalue;
begin
  v := bizgetjsonvaluebyindex(fvalue,index);
  val := TBizJsonValue.create;
  val.fvalue := v;
  val.freader := freader;
  freader.fvaluelist.add(val);
  result := val;
end;

{ TBizLocalTable }

constructor TBizLocalTable.create(aowner: tcomponent);
begin
  inherited create(aowner);
  flocaltable := tunitable.create(aowner);
  //flocaltable.fetchall := true;
  flocaltable.CachedUpdates := false;
  flocaltable.options.strictupdate := false;
  CachedUpdates := true;
  fetchall := true;
  Options.StrictUpdate := false;
end;

destructor TBizLocalTable.destroy;
var
  i: integer;
begin
  if fsession<>nil then begin
    i := fsession.flocaltablelist.IndexOf(self);
    if i>=0 then fsession.flocaltablelist.Delete(i);
  end;

  freeandnil(flocaltable);
  inherited destroy;
end;

procedure TBizLocalTable.empty;
begin
  first;
  while not eof do begin
    delete;
  end;
end;

procedure TBizLocalTable.createlocaltable(order: string; isprimary: boolean=false);
var
  i,j: integer;
  s,indexsql,createsql,s1,cfld: string;
begin
  ftablename := biztempname;
  cfld := '';
  for i := 0 to FieldDefs.Count-1 do begin
    if (FieldDefs[i].DataType=ftstring) and (fielddefs[i].size>1000) then
      s1 := FieldDefs[i].Name+' blob sub_type text'
    else
      s1 := getfielddefsql(fielddefs[i].datatype,FieldDefs[i].name,fielddefs[i].size,fielddefs[i].precision,false);

    if flocfieldlist='' then flocfieldlist := fielddefs[i].name
    else flocfieldlist := flocfieldlist+','+fielddefs[i].name;
    if cfld='' then cfld := s1
    else cfld := cfld+','+s1;
  end;

  s := stringreplace(Order,';',',',[rfreplaceall]);
  if s<>'' then begin
    i := Pos('.', S);
    while i <> 0 do begin
      for j := i downto 1 do
        if S[j] in [' ',',',';'] then break
        else S[j] := ' ';

      i := Pos('.', S);
    end;

    order := s;
    s := stringreplace(s,' desc','',[rfreplaceall]);
  end;

  forder := order;
  if isprimary then
    createsql := 'create table '+ftablename+'('+cfld+',constraint p_'+ftablename+' primary key('+s+'))'
  else
    createsql := 'create table '+ftablename+'('+cfld+')';

  bizloginfo(nil,createsql);
  try
    Connection.ExecSQL(createsql);
  except
    on e: exception do begin
      bizlogerror(mysession, createsql+','+e.message);
      raise;
    end;
  end;

  if (s<>'') and (not isprimary) then begin
    indexsql := 'create index i01_'+ftablename+' on '+ftablename+'('+s+')';
    connection.execsql(indexsql);
  end;

  refresh;
end;

procedure TBizLocalTable.refresh;
begin
  if tuniquery(self).active then
    tuniquery(self).active := false;

  sql.clear;
  if forder<>'' then
    sql.add('select '+flocfieldlist+' from '+ftablename+' order by '+forder)
  else
    sql.add('select '+flocfieldlist+' from '+ftablename);

  tuniquery(self).active := true;
  if flocaltable.active then
    flocaltable.active := false;

  flocaltable.TableName := ftablename;
  flocaltable.active := true;
end;

function TBizLocalTable.savetofile: string;
var
  dststream: tmemorystream;
  RemoteID, FieldLen, i, j: integer;
  GetType: byte;
  RecCount, DataLen: integer;
  BlobStream: TMemorystream;
  MemoryStream: TBizMemoryStream;
  MemLen, SendLen: integer;
  C: char;
  S, filename,MemoStr: string;
  l: cardinal;
  B: boolean;
  ds: tdataset;
  d: extended;
  dt: tdatetime;
begin
  filename := 'SESS'+biztempname+'.db';
  result := bizstring(@serverparam^.tmppath[1]);
  try
    BlobStream := TMemoryStream.Create;
    MemoryStream := TbizMemoryStream.Create;

    memorystream.writestring(filename);
    MemoryStream.Writeint(self.recordcount);

    memorystream.writeint(self.FieldDefs.Count);
    for i := 0 to self.FieldDefs.Count-1 do begin
      S := UpperCase(self.FieldDefs[i].Name);
      memorystream.writestring(s);
      if self.FieldDefs[i].DataType = ftWideString then begin
        memorystream.writeint(integer(ftString));
        memorystream.writeint(self.FieldDefs[i].Size);
        memorystream.writeint(0);
      end
      else begin
        if self.FieldDefs[i].DataType in [ftBCD, ftFloat, ftCurrency] then begin
          if Copy(S,1,2)='I_' then begin
            memorystream.writeint(integer(ftInteger));
            memorystream.writeint(0);
            memorystream.writeint(0);
            self.Fields[i].Tag := 8;
          end
          else begin
            memorystream.writeint(integer(ftfloat));
            memorystream.writeint(self.getfieldprecision(self.fielddefs[i].name));
            memorystream.writeint(self.getfieldscale(self.fielddefs[i].name));
          end;
        end
        else begin
          memorystream.writeint(integer(self.FieldDefs[i].DataType));
          memorystream.writeint(self.FieldDefs[i].Size);
          memorystream.writeint(0);
        end;
      end;

      //bizloginfo(inttostr(integer(self.fielddefs[i].datatype))+',size:'+inttostr(self.FieldDefs[i].Size)
      //  +','+
    end;

    DataLen := 0;
    ds := self;
    while not ds.Eof do begin
      for i := 0 to ds.FieldCount-1 do begin
        case ds.fields[i].datatype of
          ftstring,ftwidestring,ftwidememo,ftmemo:
            begin
              memorystream.writestring(ds.fields[i].asstring);
            end;
          ftinteger,ftlargeint:
            begin
              memorystream.writeint(ds.fields[i].asinteger);
            end;
          ftBCD, ftFloat, ftCurrency:
            begin
              if ds.fields[i].tag = 8 then begin
                memorystream.writeint(ds.fields[i].asinteger);
              end
              else
              begin
                d := ds.fields[i].Asfloat;
                memorystream.writeextended(d);
              end;
            end;
          ftdatetime, fttime, ftdate:
            begin
              dt := ds.fields[i].asdatetime;
              memorystream.writedatetime(dt);
            end;
          else
            begin
              if ds.Fields[i].IsBlob then begin
                BlobStream.SetSize(0);
                TBlobField(ds.Fields[i]).SaveToStream(BlobStream);
                FieldLen := BlobStream.Size;
                MemoryStream.Writeint(FieldLen);
                MemoryStream.Writebuff(PChar(BlobStream.Memory), FieldLen);
                DataLen := DataLen+FieldLen+4;
              end
              else tbizmessage.raiseerror(fsession.lang,0, 1, 'fieldtype not found:'+inttostr(integer(ds.fields[i].datatype)));
            end;
        end;
      end;

      ds.Next;
    end;

    try
      dststream := tmemorystream.create;
      bizcompress(memorystream,dststream);
      dststream.savetofile(result+filename);
    finally
      dststream.free;
    end;

    result := filename;
  finally
    BlobStream.Free;
    MemoryStream.Free;
  end;
end;

{ TBizHTML }

procedure TBizHTML.AppendCHARSET(const charset: string='');
var
  c: string;
begin
  if charset='' then c := 'utf-8'
  else c := charset;
  AppendLine('<meta http-equiv="Content-Type" content="text/html; charset='+c+'" />');
end;

procedure TBizHTML.AppendFONT(const val: string; const attribute: string=''; needreplace: boolean=false);
begin
  if attribute<>'' then
    append('<font '+attribute+'>')
  else
    append('<font>');

  if needreplace then
    append(replace(val)+'</font>')
  else
    append(val+'</font>');
end;

procedure TBizHTML.AppendH2(const val, attribute: string; needreplace: boolean);
begin
  if attribute<>'' then
    append('<h2 '+attribute+'>')
  else
    append('<h2>');

  if needreplace then
    append(replace(val)+'</h2>')
  else
    append(val+'</h2>');
end;

procedure TBizHTML.AppendLine(const Line: string; autoindent: boolean=true; needreplace: boolean=false);
begin
  if needreplace then begin
    if fcontent='' then begin
      if autoindent then
        fcontent := fixedlen('',findent, ' ')+replace(line)
      else
        fcontent := replace(line);
    end
    else begin
      if autoindent then
        fcontent := fcontent+fixedlen('',findent,' ')+#$a+replace(line)
      else
        fcontent := fcontent+#$a+replace(line);
    end;
  end
  else begin
    if fcontent='' then begin
      if autoindent then
        fcontent := fixedlen('',findent, ' ')+line
      else
        fcontent := line;
    end
    else begin
      if autoindent then
        fcontent := fcontent+fixedlen('',findent,' ')+#$a+line
      else
        fcontent := fcontent+#$a+line;
    end;
  end;
end;

procedure TBizHTML.AppendLinkCSSFile(const srcfile: string);
begin
  AppendLine('<link href="'+srcfile+'" rel="stylesheet" type="text/css" />');
end;

procedure TBizHTML.AppendP(const val: string; const attribute: string=''; needreplace: boolean=false);
begin
  if attribute<>'' then
    append('<p '+attribute+'>')
  else
    append('<p>');

  if needreplace then
    append(replace(val)+'</p>')
  else
    append(val+'</p>');
end;

procedure TBizHTML.AppendScriptFile(const srcfile: string);
begin
  AppendLine('<script src="'+srcfile+'" type="text/javascript" />');
end;

procedure TBizHTML.AppendSelect(const attribute, valkey, selectedkey: string;
  needreplace: boolean);
var
  str: tstringlist;
  i,j: integer;
  val,key: string;
  selected: boolean;
begin
  if attribute<>'' then
    appendline('<select '+attribute+'>')
  else
    appendline('<select>');

  try
    str := tstringlist.create;
    delimitstring(valkey,',',str);
    for i := 0 to str.Count-1 do begin
      j := pos('=',str[i]);
      if j>0 then begin
        val := copy(str[i],1,j-1);
        key := copy(str[i],j+1,1000);
      end
      else begin
        val := str[i];
        key := str[i];
      end;

      if (selectedkey='') and (i=0) or (selectedkey=key) then
        selected := true
      else
        selected := false;

      if selected then
        appendline('<option value="'+key+'" selected>'+val+'</option>',true,needreplace)
      else
        appendline('<option value="'+key+'">'+val+'</option>',true,needreplace);
    end;

    appendline('</select>');
  finally
    str.Free;
  end;
end;

procedure TBizHTML.AppendSPAN(const val: string; const attribute: string=''; needreplace: boolean=false);
begin
  if attribute<>'' then
    append('<span '+attribute+'>')
  else
    append('<span>');

  if needreplace then
    append(replace(val)+'</span>')
  else
    append(val+'</span>');
end;

procedure TBizHTML.AppendSTRONG(const val, attribute: string;
  needreplace: boolean);
begin
  if attribute<>'' then
    append('<strong '+attribute+'>')
  else
    append('<strong>');

  if needreplace then
    append(replace(val)+'</strong>')
  else
    append(val+'</strong>');
end;

procedure TBizHTML.AppendTITLE(const title: string; needreplace: boolean=false);
begin
  if needreplace then
    AppendLine('<title>'+replace(title)+'</title>')
  else
    AppendLine('<title></title>');
end;

procedure TBizHTML.clear;
begin
  fcontent := '';
  findent := 0;
end;

procedure TBizHTML.append(const str: string; needreplace: boolean=false);
begin
  if needreplace then
    fcontent := fcontent+replace(str)
  else
    fcontent := fcontent+str;
end;

procedure TBizHTML.AppendA(const href: string; const val: string=''; const attribute: string=''; needreplace: boolean=false);
begin
  if attribute<>'' then
    append('<a href="'+href+'" '+attribute+'>')
  else
    append('<a href="'+href+'">');

  if needreplace then
    append(replace(val)+'</a>')
  else
    append(val+'</a>');
end;

procedure TBizHTML.AppendB(const val: string; const attribute: string=''; needreplace: boolean=false);
begin
  if attribute<>'' then
    append('<b '+attribute+'>')
  else
    append('<b>');

  if needreplace then
    append(replace(val)+'</b>')
  else
    append(val+'</b>');
end;

procedure TBizHTML.CloseBODY;
begin

end;

procedure TBizHTML.CloseDIV;
begin
  findent := findent-2;
  appendline(fixedlen('',findent,' ')+'</div>');
end;

procedure TBizHTML.CloseFORM;
begin
  findent := findent-2;
  appendline(fixedlen('',findent,' ')+'</form>');
end;

procedure TBizHTML.CloseHEAD;
begin
  appendline('</head>');
end;

procedure TBizHTML.CloseHTML;
begin
  appendline('</html>');
end;

procedure TBizHTML.CloseLI;
begin
  findent := findent-2;
  appendline(fixedlen('',findent,' ')+'</li>');
end;

procedure TBizHTML.CloseSCRIPT;
begin
  appendline('</script>');
end;

procedure TBizHTML.CloseSTYLE;
begin
  appendline('</style>');
end;

procedure TBizHTML.CloseTABLE;
begin
  findent := findent-2;
  appendline(fixedlen('',findent,' ')+'</table>');
end;

procedure TBizHTML.CloseTD;
begin
  findent := findent-2;
  appendline(fixedlen('',findent,' ')+'</td>');
end;

procedure TBizHTML.CloseTR;
begin
  findent := findent-2;
  appendline(fixedlen('',findent,' ')+'</tr>');
end;

procedure TBizHTML.CloseUL;
begin
  findent := findent-2;
  appendline(fixedlen('',findent,' ')+'</ul>');
end;

constructor TBizHTML.create(l: tbizlang=langzh);
begin
  flang := l;
end;

function TBizHTML.getmsg(const msg: string): string;
var
  i: integer;
  idstr,msgstr: string;
begin
  if msg='' then begin
    result := '';//bizgetlangstr(flang);
  end
  else begin
    i := pos('.',msg);
    if i>0 then begin
      idstr := copy(msg,1,i-1);
      msgstr := copy(msg,i+1,1000);
    end
    else begin
      idstr := '0';
      msgstr := msg;
    end;

    result := tbizmessage.getmsg(flang,strtoint(idstr),strtoint(msgstr));
  end;
end;

function TBizHTML.replace(const val: string): string;
var
  i,j,k,l: Integer;
  findstr: boolean;
  str: string;
begin
  result := '';
  i := 0;
  j := length(val);
  findstr := false;
  str := '';
  while true do begin
    inc(i);
    if i>j then break;

    if val[i]='#' then begin
      if (i<j) and (val[i+1]='#') then begin
        findstr := true;
        i := i+1;
        continue;
      end;
    end;

    if (findstr) and (val[i] in ['0'..'9','.','$']) then
      str := str+val[i]
    else begin
      if not findstr then
        result := result+val[i]
      else begin
        result := result+getmsg(str)+val[i];
        findstr := false;
        str := '';
      end;
    end;
  end;

  if findstr then
    result := result+getmsg(str);
end;

procedure TBizHTML.WriteBODY(const attribute: string='');
begin
  findent := 2;
  if attribute='' then
    appendline('<body>')
  else
    appendline('<body '+attribute+'>');
end;

procedure TBizHTML.WriteDIV(const attribute: string);
begin
  if findent<2 then findent := 2;

  if attribute='' then
    append(fixedlen('',findent)+'<div>')
  else
    append(fixedlen('',findent)+'<div '+attribute+'>');
  findent := findent+2;
end;

procedure TBizHTML.WriteFORM(const attribute: string);
begin
  if findent<2 then findent := 2;
  append(fixedlen('',findent)+'<form '+attribute+'>');
  findent := findent+2;
end;

procedure TBizHTML.WriteHEAD;
begin
  appendline('<head>');
end;

procedure TBizHTML.WriteHTML;
begin
  appendline('<html>');
end;

procedure TBizHTML.writeLI(const attribute: string);
begin
  if findent<2 then findent := 2;

  if attribute='' then
    append(fixedlen('',findent)+'<li>')
  else
    append(fixedlen('',findent)+'<li '+attribute+'>');
  findent := findent+2;
end;

procedure TBizHTML.WriteSCRIPT;
begin
  appendline('<script type="text/javascript">');
end;

procedure TBizHTML.WriteSTYLE;
begin
  appendline('<style>');
end;

procedure TBizHTML.WriteTABLE(const attribute: string='');
begin
  if findent<2 then findent := 2;

  if attribute='' then
    append(fixedlen('',findent)+'<table>')
  else
    append(fixedlen('',findent)+'<table '+attribute+'>');

  findent := findent+2;
end;

procedure TBizHTML.WriteTD(const attribute: string='');
begin
  if attribute='' then
    append(fixedlen('',findent)+'<td>')
  else
    append(fixedlen('',findent)+'<td '+attribute+'>');
  findent := findent+2;
end;

procedure TBizHTML.WriteTR(const attribute: string);
begin
  if attribute='' then
    append(fixedlen('',findent)+'<tr>')
  else
    append(fixedlen('',findent)+'<tr '+attribute+'>');
  findent := findent+2;
end;

procedure TBizHTML.WriteUL(const attribute: string);
begin
  if findent<2 then findent := 2;

  if attribute='' then
    append(fixedlen('',findent)+'<ul>')
  else
    append(fixedlen('',findent)+'<ul '+attribute+'>');
  findent := findent+2;
end;

function bizfilelock(p:pchar): integer; cdecl; external 'bizutils' name 'bizfilelock';
procedure bizfileunlock(f: integer); cdecl; external 'bizutils' name 'bizfileunlock';
{ TBizLock }
constructor TBizLock.Create(LockName: string);
begin
  flockname := lockname;
  fd := bizfilelock(pchar(lockname));
end;

destructor TBizLock.destroy;
begin
  if fd>0 then bizfileunlock(fd);
  fd := 0;
  inherited destroy;
end;

{ TBizTextFile }

constructor TBizTextFile.create;
begin
  fopened := false;
end;

destructor TBizTextFile.destroy;
begin
  close;
  inherited destroy;
end;

procedure TBizTextFile.createnewfile(fname: string; ftype: TBizFileType);
begin
  if fopened then close;
  //if fileexists(fname) then raise exception.create('file exists:'+fname);
  ffile := tfilestream.Create(fname, fmcreate or fmopenreadwrite or fmsharedenynone);
  fopened := true;
  ffiletype := ftype;
  case ffiletype of
    ftutf8:
      begin
      end;
    ftunicode:
      begin
      end;
    ftansi:
      begin

      end;
  end;
end;

procedure TBizTextFile.openexistfile(fname: string; readonly: boolean; ftype: TBizFileType);
var
  i: integer;
begin
  if fopened then close;
  if readonly then
    ffile := tfilestream.Create(fname, fmopenread or fmsharedenynone)
  else
    ffile := tfilestream.Create(fname, fmopenreadwrite or fmsharedenynone);

  bizfill(@fbuf[1], 4096, chr(0));
  i := ffile.Read(fbuf, 4096);
  fbuflen := i;
  fbufpos := 0;
  ffiletype := ftype;
  if (fbuf[1]=$ef) and (fbuf[2]=$bb) and (fbuf[3]=$bf) then begin
    fbufpos := 3;
    if i<=3 then feof := true
    else feof := false;
  end
  else begin
    if i=0 then feof := true
    else feof := false;
  end;

  fopened := true;
end;

procedure TBizTextFile.close;
begin
  if fopened then freeandnil(ffile);
  flastblock := false;
  feof := false;
end;

function TBizTextFile.readln: string;
var
  s1: ansiString;
  s2: ansistring;
  i: integer;
  prevd: boolean;
begin
  result := '';
  s1 := '';
  s2 := '';
  if feof then exit;

  while true do begin
    if fbufpos>=fbuflen then begin
      bizfill(@fbuf[1], 4096, chr(0));
      i := ffile.Read(fbuf, 4096);
      fbuflen := i;
      fbufpos := 0;
      if i=0 then begin
        feof := true;
        break;
      end;
    end
    else begin
      case ffiletype of
        ftunicode:
          begin
            {
            if (fbuf[fbufpos+1]=$0d) and (fbuf[fbufpos+2]=$00) or
              (fbuf[fbufpos+1]=$0a) and (fbuf[fbufpos+2]=$00) then begin
              if (fbuf[fbufpos+1]=$0d) and (fbuf[fbufpos+2]=$00) then prevd := true
              else prevd := false;
              fbufpos := fbufpos+2;
              if fbufpos>=fbuflen then begin
                fillmemory(@fbuf[1], 4096, 0);
                i := ffile.Read(fbuf, 4096);
                fbuflen := i;
                fbufpos := 0;
                if i=0 then begin
                  feof := true;
                  break;
                end
                else begin
                  if (prevd) and (fbuf[fbufpos+1]=$0a) and (fbuf[fbufpos+2]=$00) then
                    fbufpos := fbufpos+2;

                  break;
                end;
              end
              else begin
                if (prevd) and (fbuf[fbufpos+1]=$0a) and (fbuf[fbufpos+2]=$00) then begin
                  fbufpos := fbufpos+2;
                  break;
                end;
              end;
            end
            else if (fbuf[fbufpos+1]=$0a) and (fbuf[fbufpos+2]=$00) then begin
              fbufpos := fbufpos+2;
              break;
            end
            else begin
              result := result+pchar(@fbuf[fbufpos+1])^;
              fbufpos := fbufpos+2;
            end;
            }
          end;

        ftutf8:
          begin
            if (fbuf[fbufpos+1]=$0d) or (fbuf[fbufpos+1]=$0a) then begin
              if fbuf[fbufpos+1]=$0d then prevd := true
              else prevd := false;
              fbufpos := fbufpos+1;
              if fbufpos>=fbuflen then begin
                bizfill(@fbuf[1], 4096, chr(0));
                i := ffile.Read(fbuf, 4096);
                fbuflen := i;
                fbufpos := 0;
                if i=0 then begin
                  feof := true;
                  break;
                end
                else begin
                  if (prevd) and (fbuf[fbufpos+1]=$0a) then
                    fbufpos := fbufpos+1;

                  break;
                end;
              end
              else if (prevd) and (fbuf[fbufpos+1]=$0a) then begin
                inc(fbufpos);
              end;

              break;
            end
            else if fbuf[fbufpos+1]=$0a then begin
              fbufpos := fbufpos+1;
              break;
            end
            else begin
              // s1\B2\BB\C4ܶ\A8\D2\E5Ϊutf8string\A3\AC\B7\F1\D4\F2\BB\E1\D7Զ\AFת\BB\BB\A1\A3
              s1 := s1+ansichar(fbuf[fbufpos+1]);
              fbufpos := fbufpos+1;
            end;
          end;

        ftansi:
          begin
            if (fbuf[fbufpos+1]=$0d) or (fbuf[fbufpos+1]=$0a) then begin
              if fbuf[fbufpos+1]=$0d then prevd := true
              else prevd := false;
              fbufpos := fbufpos+1;
              if fbufpos>=fbuflen then begin
                bizfill(@fbuf[1], 4096, chr(0));
                i := ffile.Read(fbuf, 4096);
                fbuflen := i;
                fbufpos := 0;
                if i=0 then begin
                  feof := true;
                  break;
                end
                else begin
                  if (prevd) and (fbuf[fbufpos+1]=$0a) then
                    fbufpos := fbufpos+1;

                  break;
                end;
              end
              else if (prevd) and (fbuf[fbufpos+1]=$0a) then begin
                inc(fbufpos);
              end;

	      break;
            end
            else if (prevd) and (fbuf[fbufpos+1]=$0a) then begin
              fbufpos := fbufpos+1;
              break;
            end
            else begin
              s2 := s2+ansichar(fbuf[fbufpos+1]);
              fbufpos := fbufpos+1;
            end;
          end;
      end;
    end;
  end;

  if fbufpos>=fbuflen then begin
    bizfill(@fbuf[1], 4096, chr(0));
    i := ffile.Read(fbuf, 4096);
    fbuflen := i;
    fbufpos := 0;
    if i=0 then begin
      feof := true;
    end;
  end;

  if ffiletype=ftutf8 then begin
    Result := s1;
  end
  else if ffiletype=ftansi then begin
    result := s2;
  end;
end;

procedure TBizTextFile.writeln(s: string; cronly: boolean);
var
  s1: string;
  s2: string;
begin
  case ffiletype of
    ftUTF8:
      begin
        if cronly then s := s+#$0a //ansichar($0a)
        else s := s+#$0d#$0a;

        ffile.write(pchar(s)^, length(s));
      end;
    ftUnicode:
      begin
        {
        if cronly then s := s+#$0a
        else s := s+#$0d#$0a;
        ffile.write(pansichar(pchar(s))^, 2*length(s));
        }
      end;
    ftAnsi:
      begin
        if cronly then s := s+#$0a //ansichar($0a)
        else s := s+#$0d#$0a;

        ffile.write(pchar(s)^, length(s));
      end;
  end;
end;

procedure TBizTextFile.write(s: string);
begin
  ffile.write(pchar(s)^, length(s));
end;

procedure TBizTextFile.appendln(s: string; cronly: Boolean);
begin
  ffile.Seek(0, soFromEnd);
  case ffiletype of
    ftUTF8:
      begin
        if cronly then s := s+ansichar($0a)
        else s := s+#$0d#$0a;

        ffile.write(pchar(s)^, length(s));
      end;
    ftUnicode:
      begin
        {
        if cronly then s := s+#$0a
        else s := s+#$0d#$0a;
        ffile.write(pansichar(pchar(s))^, 2*length(s));
        }
      end;
    ftAnsi:
      begin
        if cronly then s := s+ansichar($0a)
        else s := s+#$0d#$0a;

        ffile.write(pchar(s)^, length(s));
      end;
  end;
end;

procedure TBizTextFile.writestring(s: string);
begin
  ffile.write(pchar(s)^, length(s));
end;

{ TBizMessage }

constructor TBizMessage.Create(lang: tbizlang; SysID, MsgID: integer;
  const Param1, Param2, Param3: string);
var
  S: string;
  msg: string;
begin
  fsysid := sysid;
  fmsgid := (sysid shl 16) + msgid;
  flang := lang;

  FParam1 := Param1;
  FParam2 := Param2;
  FParam3 := Param3;

  bizloginfo(nil,'raiseerror:'+fparam1+','+fparam2+','+fparam3);
  s := getmsg(lang,sysid,msgid,param1,param2,param3);
  msg := format('#%6.6x: ', [fmsgid])+s;
  inherited create(msg);
end;

constructor TBizMessage.Create(MsgID: integer; const Param1: string;
  const Param2: string; const Param3: string);
begin
  create(langen,0,msgid,param1,param2,param3);
end;

destructor TBizMessage.Destroy;
begin
  inherited Destroy;
end;

class function TBizMessage.getmsg(mylang: tbizlang; mysysid, mymsgid: integer;
  const myParam1: string; const myParam2: string; const myParam3: string): string;
var
  s: string;
  i,j: integer;
  locmsgmap: tismap;
  function getmap(l: tbizlang): tismap;
  begin
    case mylang of
      langZh: result := zhmsgmap;
      langTr: result := trmsgmap;
      langEn: result := enmsgmap;
      langFr: result := frmsgmap;
      langDu: result := dumsgmap;
      langJp: result := jpmsgmap;
      langKr: result := krmsgmap;
      langSp: result := spmsgmap;
      langRu: result := rumsgmap;
    end;

    if result=nil then result := zhmsgmap;
  end;
begin
  i := (mysysid shl 16)+mymsgid;
  locmsgmap := getmap(mylang);
  try
    s := locmsgmap.keydata[i];
    if s='' then begin
      result := 'msgid: '+format('#%6.6x: ', [i])+' not found in message file'+inttostr(integer(mylang))+'!';
      exit;
    end;
  except
    result := 'msgid: '+format('#%6.6x: ', [i])+' not found in message file'+inttostr(integer(mylang))+'!';
    exit;
  end;

  i := 0;
  j := length(s);
  result := '';
  while true do begin
    inc(i);
    if i>j then break;

    if s[i]='%' then begin
      if (i<=j-1) and (s[i+1] in ['1','2','3']) then begin
        if s[i+1]='1' then
          result := result+myparam1
        else if s[i+1]='2' then
          result := result+myparam2
        else
          result := result+myparam3;

        inc(i);
        continue;
      end
      else begin
        result := result+s[i];
        continue;
      end;
    end
    else begin
      result := result+s[i];
    end;
  end;
end;

class procedure TBizMessage.raiseerror(mylang: tbizlang; mysysid, mymsgid: integer;
  const myParam1: string; const myParam2: string; const myParam3: string);
var
  s: string;
  ret: integer;
begin
  raise tbizmessage.Create(mylang,mysysid,mymsgid,myparam1,myparam2,myparam3);
end;

{ TBizSession }

constructor TBizSession.Create;
begin
  fquerylist := tlist.create;
  flocaltablelist := tlist.create;
  freadstream := tbizstream.create;
  fwritestream := tbizstream.create;
end;

destructor TBizSession.destroy;
begin
  if fneedexit then exitsession;
  fneedexit := false;
  freeandnil(freadstream);
  freeandnil(fwritestream);
  freeandnil(fquerylist);
  freeandnil(fstrings);
  freeandnil(fstrings1);
  freeandnil(fstrings2);
  freeandnil(fstrings3);
  inherited;
end;

function TBizSession.GetUID: integer;
begin
  result := FLoginState^.uid;
end;

function TBizSession.getusername: string;
begin
  result := bizstring(@FLoginState^.username[1]);
end;

function TBizSession.getuuid: string;
begin
  result := bizstring(@FLoginState^.uuid[1]);
end;

function TBizSession.getvariables(varname: string): string;
var
  s: string;
  p: pchar;
  i,j: integer;
begin
  s := uppercase(varname)+'=';
  j := length(s);
  result := '';
  p := searchbuf(@FLoginState^.vars[1],512, 0, 512,s,[somatchcase]);
  if p=nil then exit;
  p := p+j;
  for i := 0 to 512-(p-@FLoginState^.vars[1]+j) do begin
    if (p^=chr(0)) or (p^=chr($a)) then break;
    result := result+p^;
    p := p+1;
  end;
end;

function TBizSession.getstrings1: tstringlist;
begin
  if fstrings1 =nil then
    fstrings1 := tstringlist.create;

  result := fstrings1;
end;

function TBizSession.getintransaction: boolean;
begin
  result := fdatabase.InTransaction;
end;

function TBizSession.getislogin: boolean;
begin
  result := false;
  if FLoginState=nil then exit;
  result := (FLoginState^.islogin =1);
end;

function TBizSession.getlang: tbizlang;
begin
  if floginstate=nil then result := langzh
  else result := tbizlang(floginstate^.lang);
end;

function TBizSession.gethtml: tbizhtml;
begin
  if fhtml=nil then fhtml := tbizhtml.create(getlang)
  else fhtml.lang := getlang;
  result := fhtml;
end;

function TBizSession.getcomptype: string;
begin
  query3.fieldlist := 'c_comp_type';
  query3.tablelist := 'biz_company';
  query3.condition := 'i_comp_id='+inttostr(fcompid);
  query3.open;
  result := query3.fields[0].asstring;
end;

function TBizSession.getlangid: string;
begin
  case getlang of
    langZh: result := 'zh';
    langTr: result := 'tr';
    langEn: result := 'en';
    langFr: result := 'fr';
    langDu: result := 'du';
    langJp: result := 'jp';
    langKr: result := 'kr';
    langru: result := 'ru';
    else result := 'zh';
  end;
end;

function TBizSession.getlangstr: string;
begin
  case getlang of
    langZh: result := '中文';
    langTr: result := '中文(繁)';
    langEn: result := 'English';
    langFr: result := 'Français';
    langDu: result := 'Deutsch';
    langJp: result := '日本語';
    langKr: result := '한국어';
    langru: result := 'Pу́сский язы́к';
    else result := '中文';
  end;
end;

function TBizSession.getprefix: string;
begin
  if fcompid=0 then result := 'BIZ_'
  else result := 'Z'+trim(format('%8x_',[fcompid]));
end;

function TBizSession.getlocquery: tbizquery;
begin
  result := querylist[fappid][0];
end;

function TBizSession.getreasefilepath(ind: integer): string;
begin
  bizstring(result,@serverparam^.releasefilepath[ind][1]);
  if result[length(result)]<>'/' then result := result+'/';
end;

function TBizSession.getstrings: tstringlist;
begin
  if fstrings =nil then
    fstrings := tstringlist.create;

  result := fstrings;
end;

function TBizSession.getquery1: tbizquery;
begin
  result := querylist[fappid][1];
end;

function TBizSession.getquery2: tbizquery;
begin
  result := querylist[fappid][2];
end;

function TBizSession.getquery3: tbizquery;
begin
  result := querylist[fappid][3];
end;

function TBizSession.getstrings2: tstringlist;
begin
  if fstrings2 =nil then
    fstrings2 := tstringlist.create;

  result := fstrings2;
end;

function TBizSession.getstrings3: tstringlist;
begin
  if fstrings3 =nil then
    fstrings3 := tstringlist.create;

  result := fstrings3;
end;

function TBizSession.getdatabase: tbizdatabase;
var
  locdb: tbizdatabase;
  locdbserver: string;
  locdbport: integer;
  locdbusername: string;
  locdbpassword: string;
  locdbname: string;
  buf: array[1..64] of char;
  locquery: tbizquery;
  s: string;
begin
  result := nil;
  if fappid<=1 then begin
    bizlogerror(self,'when getdatabase, appid cannot less than 1');
    exit;
  end;

  if databaselist[fappid]=nil then begin
    locdb := tbizdatabase.create(nil);
    try
      bizstring(locdbserver,@serverparam^.dbserver[1]);
      bizstring(locdbusername,@serverparam^.dbusername[1]);
      bizstring(locdbpassword,@serverparam^.dbpassword[1]);
      bizstring(locdbname,@serverparam^.appdb[fappid][1]);
      locdbport := serverparam^.dbport;
      stringtochar(locdbpassword,@buf[1],64);
      bizdecrypt($46d8d231,$8f7e51ac,@buf[1],64);
      bizstring(locdbpassword,@buf[1]);
      s := 'ProviderName=PostgreSQL;Data Source='+locdbserver
        +';Port='+inttostr(locdbport)
        +';Database='+locdbname
        +';User ID='+locdbusername
        +';Password='+locdbpassword
        +';Connection Timeout=5;Character Set=UTF8;Login Prompt=False';
      locdb.connectstring := s;
      //bizloginfo(self,'connectstring:'+locdb.connectstring);
      locdb.Options.EnableBCD:=true;
      try
        locdb.connected := true;
      except
        on e: exception do begin
          bizloginfo(self,'connect to db error:'+e.message);
          raise;
        end;
      end;

      databaselist[fappid] := locdb;
      locquery := tbizquery.create(nil);
      locquery.connection := locdb;
      querylist[fappid][1] := locquery;

      locquery := tbizquery.create(nil);
      locquery.connection := locdb;
      querylist[fappid][2] := locquery;

      locquery := tbizquery.create(nil);
      locquery.connection := locdb;
      querylist[fappid][3] := locquery;

      locquery := tbizquery.create(nil);
      locquery.connection := locdb;
      querylist[fappid][0] := locquery;

      bizloginfo(self,'connect database-'+inttostr(fappid)+'-'+locdbname+' success!');
    except
      on e: exception do begin
        bizloginfo(self, 'getdatabase error: '+e.message);
        locdb.free;
        raise;
      end;
    end;
  end;

  fdatabase := databaselist[fappid];
  result := fdatabase;
end;

function TBizSession.getquery: tbizquery;
var
  locquery: tbizquery;
begin
  locquery := tbizquery.create(nil);
  locquery.connection := fdatabase;
  fquerylist.add(locquery);
  result := locquery;
  locquery.FSession := self;
end;

function TBizSession.getlocaltable: tbizlocaltable;
var
  src,dest,dbfile: string;
  loctable: tbizlocaltable;
  i: integer;
begin
  if flocaldb=nil then begin
    flocaldb := tuniconnection.create(nil);
    src := bizstring(@serverparam^.stddb[1]);
    dest := bizstring(@serverparam^.tmppath[1])+biztempname+'.db';
    if not bizcopyfile(src, dest) then begin
      bizlogerror(self,'copy file:'+src+' to '+dest+' error!');
      raise exception.create('copy file error!');
    end;

    flocaldb.database:= dest;
    flocaldb.SpecificOptions.add('InterBase.Charset=UTF8');
    flocaldb.SpecificOptions.add('InterBase.UseUnicode=True');
    flocaldb.SpecificOptions.add('InterBase.ClientLibrary=libfbclient.so');
    flocaldb.SpecificOptions.add('InterBase.NoDBTriggers=True');
    flocaldb.SpecificOptions.add('InterBase.SimpleNumericMap=False');
    flocaldb.Options.EnableBCD := True;
    flocaldb.Username := 'SYSDBA';
    flocaldb.LoginPrompt := False;
    flocaldb.Password := 'ebizmis';
    flocaldb.ProviderName := 'InterBase';
    flocaldb.LoginPrompt := false;
    flocaldb.Username := 'SYSDBA';
    flocaldb.Password := 'ebizmis';
    flocaldb.AutoCommit := true;
    try
      flocaldb.Connected := true;
      bizloginfo(self,'connect localdb:'+dest+' success!');
    except
      on e: exception do begin
        bizloginfo(self,'connect localdb:'+dest+' error:'+e.message);
        raise;
      end;
    end;
  end;

  result := tbizlocaltable.create(nil);
  result.fcreatefromsession := true;;
  result.Options.StrictUpdate := false;
  result.Connection := flocaldb;
  result.flocaltable.Options.StrictUpdate := false;
  result.flocaltable.Connection := flocaldb;
  result.flocaltable.CachedUpdates := false;
  result.CachedUpdates := true;

  result.fsession := self;
  flocaltablelist.add(result);
end;

procedure TBizSession.execsql(const sql: string);
var
  needcommit: boolean;
begin
  if not intransaction then begin
    starttransaction;
    needcommit := true;
  end
  else
    needcommit := false;

  try
    bizloginfo(self, 'sql: '+copy(sql,1,500));
    fdatabase.execsql(sql);
    if needcommit then
      commit;
  except
    if needcommit then
      rollback;

    raise;
  end;
end;

function TBizSession.getcomptable(const tablename: string): string;
begin
  result := getprefix+tablename;
end;

function TBizSession.getdatatablespace: string;
begin
  result := 'tspdata_'+inttostr(fcompid mod maxtablespace);
end;

function TBizSession.getindextablespace: string;
begin
  result := 'tspindex_'+inttostr(fcompid mod maxtablespace);
end;

procedure TBizSession.writeint(i: integer);
begin
  fwritestream.writeint(i);
end;

procedure TBizSession.writeint64(i: int64);
begin
  fwritestream.writeint64(i);
end;

procedure TBizSession.writestring(const val: string);
begin
  fwritestream.writestring(val);
end;

procedure TBizSession.writechar(b: char);
begin
  fwritestream.writechar(b);
end;

procedure TBizSession.writebuffer(p: pchar; len: integer);
begin
  fwritestream.writebuffer(p, len);
end;

procedure TBizSession.writelenbuffer(p: pchar; len: integer);
begin
  fwritestream.writeint(len);
  fwritestream.writebuffer(p,len);
end;

function TBizSession.writebuffer(stream: tstream; len: integer): integer;
begin
  result := fwritestream.writebuffer(stream,len);
end;

procedure TBizSession.writedatetime(dt: tdatetime);
begin
  fwritestream.writebuffer(@dt, sizeof(tdatetime));
end;

function TBizSession.readint: integer;
begin
  result := freadstream.readint;
end;

function TBizSession.readint64: integer;
begin
  result := freadstream.readint64;
end;

function TBizSession.readstring: string;
begin
  result := freadstream.readstring;
end;

function TBizSession.readchar: char;
begin
  result := freadstream.readchar;
end;

function TBizSession.readbuffer(p: pchar; len: integer): integer;
begin
  result := freadstream.readbuffer(p,len);
end;

function TBizSession.readlenbuffer(p: pchar; len: integer): integer;
var
  i: integer;
begin
  i := freadstream.readint;
  if len<i then raise exception.create('data length overflow!');
  result := freadstream.readbuffer(p,i);
  assert(result=i);
end;

function TBizSession.readdatetime: tdatetime;
begin
  result := freadstream.readdatetime;
end;

procedure TBizSession.login(l: tbizlang; cid: integer; const uname, pwd: string; var needverify: integer);
var
  s: string;
  buf: array[1..64] of char;
  pass: string;
  locuid: integer;
begin
  fcompid := cid;
  floginstate^.lang:= integer(l);
  floginstate^.islogin := 0;
  floginstate^.compid := cid;
  s := copy(uname,1,63);
  memcopy(@FLoginState^.username[1],pchar(s),length(s));
  query.FieldList := 'c_comp_name,i_status,c_lock_msg,c_mainpath,i_fingerprint,c_comp_type';
  query.TableList := 'biz_company';
  query.Condition := 'i_comp_id='+inttostr(fcompid);
  query.open;
  if query.eof then
    tbizmessage.raiseerror(l,0,1,'公司没有找到')
  else if query.Fields[1].AsInteger=1 then begin
    //if session.query.Fields[2].AsString<>'' then raise tbizmessage.Create(1,'系统临时锁定：'+session.query.Fields[2].asstring)
    //else raise tbizmessage.Create(1,'系统临时锁定，请联系管理员');
  end
  else if query.Fields[1].AsInteger=3 then begin
    tbizmessage.raiseerror(l,0,1,'系统正升级至正式运行环境中，请联系管理员');
  end
  else if query.Fields[1].AsInteger=8 then begin
    tbizmessage.raiseerror(l,0,1,'已经升级到正式服务器，请选择正式服务器登录');
  end;

  if query.fields[1].asinteger=2 then needverify := 1
  else needverify := 0;
  fcompname := query.fields[0].asstring;
  query.fieldlist := '*';
  query.tablelist := getcomptable('user');
  query.condition := 'upper(c_name)='''+uppercase(uname)+'''';
  query.open;
  if query.eof then tbizmessage.raiseerror(l,0,1,'用户名与密码不符');
  stringtochar(query.fieldbyname('c_password').asstring,@buf[1],64);
  bizdecrypt($46d8d231,$8f7e51ac,@buf[1],64);
  bizstring(pass,@buf[1]);
  if pass<>pwd then tbizmessage.raiseerror(l,0,1,'用户名与密码不符');
  locuid := query.fieldbyname('i_user_id').asinteger;
  if query.fieldbyname('i_user_id').asinteger<>1 then begin
    query.fieldlist := '*';
    query.tablelist := getcomptable('systemright');
    query.condition := 'i_sys_id='+inttostr(fappid)+' and i_user_id='+inttostr(locuid);
    query.open;
    if (query.eof) or (query.fieldbyname('i_right').asinteger<>1) then
      tbizmessage.raiseerror(l,0,1,'此用户没有授权登录系统');
  end;

  floginstate^.islogin := 1;
  floginstate^.uid := locuid;
end;

function TBizSession.gettime(loctm: tdatetime): tdatetime;
begin
  result := loctm;
end;

function TBizSession.regetwxtoken: string;
var
  js: tjsonobject;
  idhttp1: tidhttp;
  s,s1,s2,s3,filename: string;
  lock: tbizlock;
  txtfile: tbiztextfile;
  rq1: tdatetime;
begin
  filename := tmppath+'WX-'+servername+'-'+inttostr(appid);
  try
    idhttp1 := tidhttp.create(nil);
    js := nil;
    s := idhttp1.Get('https://api.weixin.qq.com/cgi-bin/token?grant_type=client_credential&'
      +'appid='+wxapps[appid].wxappid+'&secret='+wxapps[appid].wxsecret);
    s2 := 'get token for '+wxapps[appid].appname+': '+s;
    bizloginfo(nil,s2);
    js := TJSONObject(GetJson(s));
    s := bizunquote(js.get('access_token',''));

    // get jsticket
    s1 := idhttp1.Get('https://api.weixin.qq.com/cgi-bin/ticket/getticket?access_token='+s+'&type=jsapi');
    bizloginfo(nil,'get jsticket for '+wxapps[appid].appname+': '+s1);
    js := TJSONObject(GetJson(s1));
    s1 := bizunquote(js.Get('ticket',''));
    try
      lock := tbizlock.create(servername);
      txtfile := tbiztextfile.create;
      bizloginfo(nil,'write to file:'+filename);
      txtfile.createnewfile(filename);
      s3 := formatdatetime('yyyy-mm-dd hh:nn:ss',now);
      txtfile.writeln(s3);
      txtfile.writeln(s);
      txtfile.writeln(s1);
    finally
      txtfile.free;
      lock.free;
    end;
  finally
    freeandnil(idhttp1);
    freeandnil(js);
  end;

  result := s;
end;

procedure TBizSession.initsession(mystate: PBizLoginState);
begin
  floginstate := mystate;
  fdatabase := nil;
  //flocaldb := nil;
  fcompid := 0;
  if mystate<>nil then begin
    fappid := mystate^.appid;
    fcompid := mystate^.compid;
    fremoteaddr := bizstring(@mystate^.remoteaddr[1]);
    fremotedevice := bizstring(@mystate^.remotedevice[1]);

    if fappid>1 then begin
      getdatabase;
    end;

    if fhtml=nil then
      fhtml := tbizhtml.create;

    fhtml.lang := tbizlang(mystate^.lang);
    fhtml.clear;
  end;

  if fappid=7 then fstartcompid := 8001;
  fneedexit := true;
end;

procedure TBizSession.exitsession;
var
  locquery: tbizquery;
  loctable: tbizlocaltable;
  i: integer;
  dbfile: string;
begin
  for i := 0 to flocaltablelist.count-1 do begin
    loctable := tbizlocaltable(flocaltablelist[i]);
    loctable.free;
  end;

  flocaltablelist.clear;

  for i := 0 to fquerylist.count-1 do begin
    locquery := tbizquery(fquerylist[i]);
    locquery.free;
  end;

  if flocaldb<>nil then begin
    dbfile := flocaldb.Database;
    if (dbfile<>'') and (bizfilesize(dbfile)>maxlocaldbsize) then begin
      flocaldb.connected := false;
      freeandnil(flocaldb);
      deletefile(dbfile);
    end;
  end;

  fquerylist.clear;
  if (querylist[fappid][0]<>nil) and (querylist[fappid][0].active) then
    querylist[fappid][0].active := false;

  if (querylist[fappid][1]<>nil) and (querylist[fappid][1].active) then
    querylist[fappid][1].active := false;

  if (querylist[fappid][2]<>nil) and (querylist[fappid][2].active) then
    querylist[fappid][2].active := false;

  if (querylist[fappid][3]<>nil) and (querylist[fappid][3].active) then
    querylist[fappid][3].active := false;

  if (fdatabase<>nil) and (fdatabase.intransaction) then begin
    bizlogerror(self, 'cannot be in transaction when exitsession, rollback!');
    fdatabase.rollback;
    fappid := 0;
    fdatabase := nil;
  end;

  fneedexit := false;
end;

procedure TBizSession.starttransaction;
begin
  fdatabase.StartTransaction(ilReadCommitted,false);
end;

function TBizSession.getwxaccesstoken: string;
var
  txtfile: tbiztextfile;
begin
  result := '';
  if not fileexists(tmppath+'/WX-'+servername+'-'+inttostr(appid)) then begin
    bizlogerror(self, 'cannot find accesstoken file for '+servername+','+inttostr(appid));
    exit;
  end;

  try
    txtfile := tbiztextfile.create;
    txtfile.openexistfile(tmppath+'/WX-'+servername+'-'+inttostr(appid));
    txtfile.readln;
    result := txtfile.readln;
  finally
    txtfile.free;
  end;
end;

function TBizSession.getwxappid: string;
begin
  result := bizstring(@serverparam^.wxappid[fappid][1]);
end;

function TBizSession.getwxid: string;
begin
  result := bizstring(@FLoginState^.wxid[1]);
end;

function TBizSession.getwxjsticket: string;
var
  txtfile: tbiztextfile;
begin
  result := '';
  if not fileexists(tmppath+'/WX-'+servername+'-'+inttostr(appid)) then begin
    bizlogerror(self, 'cannot find accesstoken file for '+servername+','+inttostr(appid));
    exit;
  end;

  try
    txtfile := tbiztextfile.create;
    txtfile.openexistfile(tmppath+'/WX-'+servername+'-'+inttostr(appid));
    txtfile.readln;
    txtfile.readln;
    result := txtfile.readln;
  finally
    txtfile.free;
  end;
end;

function TBizSession.getwxsecret: string;
begin
  result := bizstring(@serverparam^.wxsecret[fappid][1]);
end;

procedure TBizSession.setusername(AValue: string);
begin
  strcopy(@FLoginState^.username[1], pchar(avalue));
end;

procedure TBizSession.setvariables(varname: string; AValue: string);
var
  s1,s,s2: string;
  p: pchar;
  i,j,k: integer;
begin
  s := uppercase(varname)+'=';
  j := length(s);
  s2 := bizstring(@FLoginState^.vars[1],512);
  i := pos(s,s2);
  if i>0 then begin
    s1 := copy(s2,1,i-1+j)+avalue+chr($a);
    for k := i+j to length(s2) do begin
      if s2[k]=chr($a) then break;
    end;

    s1 := s1+copy(s2, k+1,512);
  end
  else begin
    s1 := s+avalue+chr($a);
  end;

  memcopy(@FLoginState^.vars[1], pchar(s1), length(s1)+1);
end;

procedure TBizSession.commit;
begin
  fdatabase.commit;
end;

procedure TBizSession.rollback;
begin
  fdatabase.rollback;
end;

function TBizSession.getglobalsequence(seqid: integer; update: boolean
  ): integer;
var
  locQuery: TBizQuery;
  j: integer;
  needcommit: boolean;
begin
  if fdatabase=nil then getdatabase;
  if not fdatabase.intransaction then begin
    needcommit := true;
    starttransaction;
  end
  else
    needcommit := false;

  try
    try
      locQuery := getquery;
      locQuery.FieldList := 'i_used';
      locQuery.TableList := 'biz_sequence';
      locQuery.Condition := 'i_id='+IntToStr(SeqID);
      locQuery.Open;
      if locQuery.EOF then begin
        ExecSQL('insert into biz_sequence values('+IntToStr(SeqID)+',1024,''auto insert'')');
        result := 1025;
      end
      else
        Result := locQuery.Fields[0].AsInteger+1;

      if Update then begin
        ExecSQL('update biz_sequence set i_used='+IntToStr(Result)+' where i_id='+IntToStr(SeqID))
      end;
    finally
      locQuery.Free;
    end;

    if needcommit then
      commit;
  except
    if needcommit then rollback;
    raise;
  end;
end;

procedure TBizSession.setweblogin(const strwxid, strusername: string;
  nuid: integer; const loclang: string);
begin
  //fwxid := strwxid;
  //fusername := strusername;
  //fuid := nuid;
  floginstate^.islogin := 1;
end;

function TBizSession.getsequence(seqid: integer; update: boolean): integer;
var
  locQuery: TBizQuery;
  j: integer;
  needcommit: boolean;
begin
  //if not fdatabase.intransaction then begin
  //  needcommit := true;
  //  starttransaction;
  //end
  //else
  //  needcommit := false;

  //try
    try
      locQuery := getquery;
      locQuery.FieldList := 'i_used';
      locQuery.TableList := getcomptable('sequence');
      locQuery.Condition := 'i_id='+IntToStr(SeqID);
      locQuery.Open;
      if locQuery.EOF then begin
        ExecSQL('insert into '+getcomptable('sequence')+' values('+IntToStr(SeqID)+',1024,''auto insert'')');
        result := 1025;
      end
      else
        Result := locQuery.Fields[0].AsInteger+1;

      if Update then begin
        ExecSQL('update '+getcomptable('sequence')+' set i_used='+IntToStr(Result)+' where i_id='+IntToStr(SeqID))
      end;
    finally
      locQuery.Free;
    end;

    //if needcommit then
    //  commit;
  //except
    //if needcommit then rollback;
    //raise;
  //end;
end;

procedure TBizSession.Insert(const TableName, FieldList: string;
  const Args: array of const);
var
	SQL, S: string;
  i: integer;
  DateTime: TDateTime;
  locstrings: tstringlist;
begin
  try
    locstrings := tstringlist.Create;
    DelimitString(FieldList, ',', locstrings);
    SQL := 'insert into '+TableName+'('+FieldList+')'+' values(';
    for i := 0 to locstrings.Count-1 do
    begin
      with Args[i] do
      case VType of
        vtInteger: SQL := SQL+IntToStr(VInteger);
        vtInt64: SQL := SQL+inttostr(VInt64^);
        vtBoolean: SQL := SQL+IntToStr(Integer(VBoolean));
        vtChar: SQL := SQL+''''+VChar+'''';
        vtWideChar: SQL := SQL+''''+VWideChar+'''';
        vtExtended: SQL := SQL+FloatToStr(VExtended^);
        vtunicodestring:
          begin
            S := string(VUnicodeString);
            SQL := SQL+''''+StringReplace(S, '''', '''''', [rfReplaceAll])+'''';
          end;
        vtString:
          begin
            S := VString^;
            SQL := SQL+''''+StringReplace(S, '''', '''''', [rfReplaceAll])+'''';
          end;
        vtPChar: SQL := SQL+''''+StringReplace(S, '''', '''''', [rfReplaceAll])+'''';
        vtPointer:
        begin
          //S := BytesToString(PLBytes(VPointer));
          //SQL := SQL+S;
        end;
        vtAnsiString:
          begin
            S := string(VAnsiString);
            SQL := SQL+''''+StringReplace(S, '''', '''''', [rfReplaceAll])+'''';
          end;
        vtVariant:
          begin
            case TVarData(VVariant^).VType of
              varDate:
                begin
                  DateTime := TDateTime(TVarData(VVariant^).VDate);
                  if (Int(DateTime) = 0) or (int(datetime)=1) then SQL := SQL+'null'
                  else SQL := SQL+''''+FormatDateTime('yyyymmdd hh:nn:ss', TDateTime(TVarData(VVariant^).VDate))+'''';
                end;
              varDouble:
                begin
                  DateTime := TDateTime(TVarData(VVariant^).VDouble);
                  if (Int(DateTime) = 0) or (int(datetime)=1) then SQL := SQL+'null'
                  else SQL := SQL+''''+FormatDateTime('yyyymmdd hh:nn:ss', DateTime)+'''';
                end;
              varInteger:
                  begin
                    DateTime := TVarData(VVariant^).VInteger;
                    if (Int(DateTime) = 0) or (int(datetime)=1) then SQL := SQL+'null'
                    else SQL := SQL+''''+FormatDateTime('yyyymmdd hh:nn:ss', DateTime)+'''';
                  end;
              else
                raise tbizMessage.Create($0001,'没有variant'+IntToStr(integer(TVarData(VVariant^).VType))+'类型');
            end;
          end;
        vtCurrency: SQL := SQL+CurrToStr(VCurrency^);
      else
        raise tbizMessage.Create($0023);
      end;

      if i = locstrings.Count-1 then SQL := SQL+')'
      else SQL := SQL+',';
    end;

    //bizappendline('/root/sql.txt',sql);
    ExecSQL(SQL);
  finally
    locstrings.Free;
  end;
end;

procedure TBizSession.Insert(DataSet: TDataSet; const TableName,
  FieldList: string; AllRecord: boolean);
var
  rec,curr,i: integer;
  field: tfield;
  fields: tstringlist;
  myfieldlist,sql,condition: string;
begin
  try
    Dataset.DisableControls;
    rec := dataset.recordcount;
    curr := 0;
    if (DataSet.BOF) and (DataSet.EOF) then exit;
    if allrecord then DataSet.First;
    try
      Fields := TStringList.Create;
      MyFieldList := FieldList;
      if (MyFieldList = '*') or (MyFieldList='') then begin
        Fields.Clear;
        for i := 0 to DataSet.Fields.Count-1 do begin
          if i = 0 then
            MyFieldList := DataSet.Fields[i].FieldName
          else
            MyFieldList := MyFieldList+','+DataSet.Fields[i].FieldName;

          Fields.Add(DataSet.Fields[i].FieldName);
        end;
      end
      else begin
        DelimitString(FieldList, ',', Fields);
      end;

      while true do begin
        inc(curr);
        SQL := 'insert into '+TableName+'('+myfieldlist+') values(';

        for i := 0 to Fields.Count-1 do
        begin
          Field := DataSet.FieldByName(Fields[i]);
          if Field = nil then raise tbizmessage.Create($0001,'栏位：'+Fields[i]+'找不到');
          if Field.FieldKind<>fkData then Continue;
          SQL := SQL+GetFieldSQLText(Field);

          if i <> Fields.Count-1 then SQL := SQL+','
          else sql := sql+')';
        end;

        ExecSQL(SQL);
        if allrecord then DataSet.Next
        else break;

        if dataset.eof then break;
      end;
    finally
      Fields.Free;
    end;
  finally
    Dataset.EnableControls;
  end;
end;

procedure TBizSession.Update(const TableName, FieldList, Condition: string;
  const Args: array of const);
var
	SQL, S: string;
  i: integer;
  DateTime: TDateTime;
  locstrings: tstringlist;
begin
  try
    locstrings := tstringlist.Create;
    DelimitString(FieldList, ',', locstrings);
    SQL := 'update '+TableName+' set ';
    for i := 0 to locstrings.Count-1 do
    begin
      //bizloginfo(nil,inttostr(i)+':'+locstrings[i]+','+inttostr(integer(args[i].vtype))+','+sql);
      with Args[i] do
      case VType of
        vtInteger: SQL := SQL+locStrings[i]+'='+IntToStr(VInteger);
        vtInt64: SQL := SQL+locStrings[i]+'='+IntToStr(VInt64^);
        vtBoolean: SQL := SQL+locStrings[i]+'='+IntToStr(Integer(VBoolean));
        vtChar: SQL := SQL+locStrings[i]+'='+''''+VChar+'''';
        vtExtended: SQL := SQL+locStrings[i]+'='+FloatToStr(VExtended^);
        vtunicodestring:
          begin
            S := string(VUnicodeString);
            SQL := SQL+locStrings[i]+'='+''''+StringReplace(S, '''', '''''', [rfReplaceAll])+'''';
          end;
        vtString:
          begin
            S := VString^;
            SQL := SQL+locStrings[i]+'='+''''+StringReplace(S, '''', '''''', [rfReplaceAll])+'''';
          end;
        vtPChar:
          begin
            SetString(S, VPChar, StrLen(VPChar));
            SQL := SQL+locstrings[i]+'='+''''+StringReplace(S, '''', '''''', [rfReplaceAll])+'''';
          end;
        vtPointer:
          begin
            //S := BytesToString(PLBytes(VPointer));
            //SQL := SQL+strings[i]+'='+S;
          end;
        vtAnsiString:
          begin
            S := string(VAnsiString);
            SQL := SQL+locstrings[i]+'='+''''+StringReplace(S, '''', '''''', [rfReplaceAll])+'''';
          end;
        vtVariant:
          begin
            case TVarData(VVariant^).VType of
              varDate:
                begin
                  DateTime := TDateTime(TVarData(VVariant^).VDate);
                  if (Int(DateTime) = 0) or (int(datetime)=1) then SQL := SQL+locStrings[i]+'=null'
                  else SQL := SQL+locstrings[i]+'='''+FormatDateTime('yyyymmdd hh:nn:ss', TDateTime(TVarData(VVariant^).VDate))+'''';
                end;
              varDouble:
                begin
                  DateTime := TDateTime(TVarData(VVariant^).VDouble);
                  if (Int(DateTime) = 0) or (int(datetime)=1) then SQL := SQL+locstrings[i]+'=null'
                  else SQL := SQL+locstrings[i]+'='''+FormatDateTime('yyyymmdd hh:nn:ss', DateTime)+'''';
                end;
              varInteger:
                begin
                  DateTime := TVarData(VVariant^).VInteger;
                  if (Int(DateTime) = 0) or (int(datetime)=1) then SQL := SQL+locstrings[i]+'=null'
                  else SQL := SQL+locstrings[i]+'='''+FormatDateTime('yyyymmdd hh:nn:ss', DateTime)+'''';
                end;
              else
                raise tbizMessage.Create($0001,'没有variant'+IntToStr(integer(TVarData(VVariant^).VType))+'类型');
            end;
          end;
        vtCurrency: SQL := SQL+locstrings[i]+'='+CurrToStr(VCurrency^);
      else
        raise tbizMessage.Create($0023);
        {	vtInterface,vtWideString,vtObject,
          vtClass,vtWideChar,vtPWideChar }
      end;

      if i <> locstrings.Count-1 then SQL := SQL+',';
    end;

    if Trim(Condition) <> '' then SQL := SQL+' where '+Condition;
    ExecSQL(SQL);
  finally
    locstrings.Free;
  end;
end;

procedure TBizSession.Update(DataSet: TDataSet; const TableName, FieldList,
  KeyFields: string; UpdateAll: boolean);
var
	SQL, S: string;
  i: integer;
  DateTime: TDateTime;
  Field: TField;
  MyBuffer: pointer;
  MyFieldList: string;
  Condition: string;
  Fields,locstrings: TStringList;
  blobstream: tmemorystream;
  needcommit,hasblob: boolean;
begin
  if (DataSet.BOF) and (DataSet.EOF) then exit;
  if UpdateAll then DataSet.First;
  if (fdatabase=nil) or (not fdatabase.InTransaction) then begin
    NeedCommit := True;
    starttransaction;
  end
  else needcommit := false;

  try
    try
      Fields := TStringList.Create;
      locstrings := tstringlist.create;
      if KeyFields <> '' then
        DelimitString(KeyFields,',',locStrings);

      MyFieldList := FieldList;
      if (MyFieldList = '*') or (MyFieldList='') then begin
        Fields.Clear;
        for i := 0 to DataSet.Fields.Count-1 do begin
          if i = 0 then
            MyFieldList := DataSet.Fields[i].FieldName
          else
            MyFieldList := MyFieldList+','+DataSet.Fields[i].FieldName;
          Fields.Add(DataSet.Fields[i].FieldName);
        end;
      end
      else
        DelimitString(FieldList, ',', Fields);

      hasblob := false;
      while not DataSet.Eof do begin
        SQL := 'update '+TableName+' set ';

        for i := 0 to Fields.Count-1 do
        begin
          Field := DataSet.FieldByName(Fields[i]);
          if Field = nil then raise tbizMessage.Create($0001,'栏位：'+Fields[i]+'找不到');
          SQL := SQL+Fields[i]+'='+GetFieldSQLText(Field);

          if i <> Fields.Count-1 then SQL := SQL+',';
        end;

        Condition := '';
        if KeyFields <> '' then begin
          for i := 0 to locStrings.Count-1 do begin
            Field := DataSet.FieldByName(locStrings[i]);
            if Field = nil then raise tbizMessage.Create($0001,'栏位：'+locStrings[i]+'找不到');
            Condition := Condition+locStrings[i]+'='+GetFieldSQLText(Field);
            if i<> locStrings.Count-1 then Condition := Condition+' and ';
          end;
        end;

        if Condition <> '' then SQL := SQL+' where '+Condition;
        ExecSQL(SQL);
        {
        if HasBlob then begin
          try
            BlobStream := TMemoryStream.Create;
            for i := 0 to Fields.Count-1 do begin
              Field := DataSet.FieldByName(Fields[i]);
              if Field.IsBlob then begin
                BlobStream.Clear;
                TBlobField(Field).SaveToStream(BlobStream);
                WriteBlobField(self.database,tablename,fields[i],Condition, BlobStream);
              end;
            end;
          finally
            BlobStream.Free;
          end;
        end;
        }
        if UpdateAll then DataSet.Next
        else break;
      end;
    finally
      Fields.Free;
      locstrings.free;
    end;

    if NeedCommit then self.Commit;
  except
    if NeedCommit then self.Rollback;
    raise;
  end;
end;

procedure TBizSession.Update(DataSet: TDataSet; const LocateFields: string;
  const LocateValue: array of const; const TableName, FieldList: string);
var
  V: variant;
  ItemCount, i: integer;
  a: array of integer;
begin
  ItemCount := High(LocateValue);
  if ItemCount = 0 then
    V := GetVariant(LocateValue[0])
  else begin
    V := VarArrayCreate([0,ItemCount],varVariant);
    for i := 0 to ItemCount do
      V[i] := GetVariant(LocateValue[i]);
  end;

  if not DataSet.Locate(LocateFields, V, []) then
    raise tbizMessage.Create($0001,'定位不到记录');
  Update(DataSet, TableName, FieldList, LocateFields);
end;

procedure TBizSession.Delete(const TableName, Condition: string);
var
	SQL: string;
begin
	SQL := 'delete from '+TableName;
  if Trim(Condition) <> '' then SQL := SQL+' where '+Condition;
  ExecSQL(SQL);
end;

{ LQuery }

procedure TBizQuery.SetFieldList(const Value: string);
begin
  FFieldList := Value;
  FCondition := '';
	FOrder := '';
	FTableList := '';
  FGroup := '';
  FHaving := '';
  flimit := 0;
  foffset := 0;
end;

constructor TBizQuery.create(aowner: tcomponent);
begin
  inherited create(aowner);
  fetchall := true;
end;

destructor TBizQuery.destroy;
var
  i: integer;
begin
  if fsession<>nil then begin
    i := fsession.fquerylist.IndexOf(self);
    if i>=0 then fsession.fquerylist.Delete(i);
  end;

  inherited destroy;
end;

function TBizQuery.getsqlstmt: string;
var
  select: string;
begin
  Select := 'select ' + FieldList + ' from ' + FTableList;
  if (Trim(FCondition) <> '') then Select := Select + ' where ' + FCondition;
  if (Trim(FGroup) <> '') then Select := Select + ' group by ' + FGroup;
  if (Trim(FHaving) <> '') then Select := Select + ' having ' + FHaving;
  if (Trim(FOrder) <> '') then Select := Select + ' order by ' + FOrder;
  if fcondition='1=2' then select := select+' limit 0'
  else if flimit>0 then select := select+' limit '+inttostr(flimit);

  if foffset>0 then select := select+' offset '+inttostr(foffset);
  if (connection<>nil) and (connection.intransaction) then begin
    if (pos('max(',select)=0) and (pos('count(',select)=0) and (pos('sum(',select)=0) then
      select := select+' for update';
  end;

  result := select;
end;

procedure TBizQuery.Duplicate(LocTable: TBizLocalTable; const primary: string='');
var
  i,j,k: integer;
  ds: tdataset;
  s,s1,createsql,indexsql,tablename,locfieldlist,locorder: string;
  blobstream: tmemorystream;
begin
  if not loctable.fcreatefromsession then
    raise exception.Create('请通过Session.GetLocalTable创建duplicate的数据表');

  if loctable.active then loctable.active := false;
  if loctable.db.active then loctable.db.active := false;
  //loctable.TableName := '<'+biztempname+'>';
  //loctable.FieldDefs.Clear;
  //loctable.indexdefs.clear;
  tablename := biztempname;
  ds := self;
  s := '';
  locfieldlist := '';
  locorder := '';
  for i := 0 to ds.FieldDefs.Count-1 do begin
    //bizloginfo(nil, ds.FieldDefs[i].name+','+inttostr(ds.fielddefs[i].size));
    if (ds.FieldDefs[i].DataType=ftstring) and (ds.fielddefs[i].size>1000) then
      s1 := ds.FieldDefs[i].Name+' blob sub_type text'
    else
      s1 := getfielddefsql(ds.fielddefs[i].datatype,ds.FieldDefs[i].name,ds.fielddefs[i].size,ds.fielddefs[i].precision,true);

    if locfieldlist='' then locfieldlist := ds.fielddefs[i].name
    else locfieldlist := locfieldlist+','+ds.fielddefs[i].name;
    if s='' then s := s1
    else s := s+','+s1;
  end;

  if primary<>'' then
    createsql := 'create table '+tablename+'('+s+', constraint p_'+tablename+' primary key('+primary+'))'
  else
    createsql := 'create table '+tablename+'('+s+')';

  bizloginfo(mysession,createsql);
  try
    loctable.Connection.ExecSQL(createsql);
  except
    on e: exception do begin
      bizlogerror(mysession, createsql+','+e.message);
      raise;
    end;
  end;

  s := FOrder;
  if s<>'' then begin
    //S := StringReplace(FOrder, ',', ';', [rfReplaceAll]);
    //S := UpperCase(S);
    i := Pos('.', S);
    while i <> 0 do begin
      for j := i downto 1 do
        if S[j] in [' ',',',';'] then break
        else S[j] := ' ';

      i := Pos('.', S);
    end;

    locorder := s;
    s := stringreplace(s,' desc','',[rfreplaceall]);
    indexsql := 'create index i01_'+tablename+' on '+tablename+'('+s+')';
    bizloginfo(mysession,indexsql);
    loctable.connection.execsql(indexsql);
  end;

  loctable.db.TableName := tablename;
  loctable.db.active := true;
  bizloginfo(nil, 'duplicate:'+inttostr(ds.recordcount)+','+ftablelist+','+ffieldlist);
  ds.first;
  k := 0;
  try
    BlobStream := TMemoryStream.Create;
    try
      while not ds.eof do begin
        inc(k);

        bizloginfo(nil,inttostr(k));
        loctable.db.insert;
        for i := 0 to ds.fieldcount-1 do begin
          if ds.fields[i].isblob then begin
            BlobStream.SetSize(0);
            TBlobField(ds.Fields[i]).SaveToStream(BlobStream);
            tblobfield(loctable.fields[i]).loadfromstream(blobstream);
          end
          else begin
            case ds.fields[i].datatype of
              ftwidestring,ftstring,ftmemo:
                begin
                  //bizloginfo(nil,ds.fields[i].asstring);
                  loctable.db.fields[i].asstring := ds.fields[i].asstring;

                end;

              ftinteger,ftlargeint:
                loctable.db.fields[i].asinteger := ds.fields[i].asinteger;

              ftdatetime,fttime,ftdate:
                begin
                  loctable.db.fields[i].asdatetime := ds.fields[i].asdatetime;
                  if loctable.db.fields[i].asdatetime<=1 then
                    loctable.db.fields[i].setdata(nil);
                end;

              ftBCD, ftFloat, ftCurrency:
                loctable.db.fields[i].asfloat := ds.fields[i].asfloat;

              else
                begin
                  raise Exception.Create('fieldtype not found:'+inttostr(integer(ds.fields[i].datatype)));
                  //field1.IsNull := true;
                end;
            end;
          end;
        end;

        loctable.db.post;
        //if (ftablelist = 'biz_wqmatchattendee') and (ffieldlist='*') then
        //  bizloginfo(nil,inttostr(k)+':'+ds.fieldbyname('c_user').asstring+','+loctable.db.fieldbyname('c_user').asstring);

        ds.next;
      end;

    except
      raise;
    end;
  finally
    BlobStream.Free;
  end;

  loctable.db.active := false;
  loctable.db.active := true;
  loctable.sql.clear;
  if locorder<>'' then
    loctable.sql.add('select '+locfieldlist+' from '+tablename+' order by '+locorder)
  else
    loctable.sql.add('select '+locfieldlist+' from '+tablename);

  tuniquery(loctable).active := true;
  //loctable.first;
  {
  if (ftablelist = 'biz_wqmatchattendee') and (ffieldlist='*') then begin
     k := 0;
     while not loctable.eof do begin
       inc(k);
       bizloginfo(nil,inttostr(k)+':'+loctable.fieldbyname('c_user').asstring);
       loctable.next;
     end;
     loctable.first;
  end;
  }
  bizloginfo(nil,'duplicate end:'+inttostr(loctable.db.recordcount)+','+inttostr(loctable.recordcount));
end;

procedure TBizQuery.open(const sql1: string);
var
  Select: string;
  ansisql,error: ansistring;
  i: integer;
begin
  if sql1<>'' then
    select := sql1
  else begin
    Select := 'select ' + FieldList + ' from ' + FTableList;
    if (Trim(FCondition) <> '') then Select := Select + ' where ' + FCondition;
    if (Trim(FGroup) <> '') then Select := Select + ' group by ' + FGroup;
    if (Trim(FHaving) <> '') then Select := Select + ' having ' + FHaving;
    if (Trim(FOrder) <> '') then Select := Select + ' order by ' + FOrder;
    // 0: struct+data,1:struct,2:data
    if fcondition='1=2' then select := select+' limit 0'
    else if flimit>0 then select := select+' limit '+inttostr(flimit);

    if foffset>0 then select := select+' offset '+inttostr(foffset);
    if (connection<>nil) and (connection.intransaction) then begin
      if (pos('max(',select)=0) and (pos('count(',select)=0) and (pos('sum(',select)=0) then
        select := select+' for update';
    end;
  end;

  try
    if active then active := false;
    sql.clear;
    sql.add(select);
    try
      active := true;
      bizloginfo(mysession,'sql:'+inttostr(self.recordcount)+','+select);
    except
      on e: exception do begin
        bizloginfo(mysession,'error:'+e.message+',sql:'+select);
        raise;
      end;
    end;
  finally
    flimit := 0;
    foffset := 0;
  end;
end;

function TBizQuery.duplicatetofile: string;
var
  i,j: integer;
  ds: tdataset;
  src,s,s1,createsql,indexsql,tablename: string;
  blobstream: tmemorystream;
  loctable: tbizlocaltable;
  locdb: tuniconnection;
begin
  result := bizstring(@serverparam^.tmppath[1])+biztempname+'.db';
  try
    locdb := tuniconnection.create(nil);
    loctable := tbizlocaltable.create(nil);

    src := bizstring(@serverparam^.stddb[1]);
    if not bizcopyfile(src, result) then begin
      bizlogerror(mysession,'copy duplicate to file:'+src+' to '+result+' error!');
      raise exception.create('copy file error!');
    end;

    locdb.database:= result;
    locdb.SpecificOptions.add('InterBase.Charset=UTF8');
    locdb.SpecificOptions.add('InterBase.UseUnicode=True');
    locdb.SpecificOptions.add('InterBase.ClientLibrary=libfbclient.so');
    locdb.SpecificOptions.add('InterBase.NoDBTriggers=True');
    locdb.SpecificOptions.add('InterBase.SimpleNumericMap=False');
    locdb.Options.EnableBCD := True;
    locdb.Username := 'SYSDBA';
    locdb.LoginPrompt := False;
    locdb.Password := 'ebizmis';
    locdb.ProviderName := 'InterBase';
    locdb.LoginPrompt := false;
    locdb.Username := 'SYSDBA';
    locdb.Password := 'ebizmis';
    locdb.AutoCommit := true;
    locdb.Connected := true;

    loctable.Connection := locdb;
    tablename := 'mytable';
    ds := self;
    s := '';
    for i := 0 to ds.FieldDefs.Count-1 do begin
      if (ds.FieldDefs[i].DataType=ftstring) and (ds.fielddefs[i].size>300) then
        s1 := ds.FieldDefs[i].Name+' blob sub_type text'
      else
        s1 := getfielddefsql(ds.fielddefs[i].datatype,ds.FieldDefs[i].name,ds.fielddefs[i].size,ds.fielddefs[i].precision);

      if s='' then s := s1
      else s := s+','+s1;
    end;

    createsql := 'create table '+tablename+'('+s+')';
    bizloginfo(mysession,createsql);
    try
      loctable.Connection.ExecSQL(createsql);
    except
      on e: exception do begin
        bizlogerror(mysession, createsql+','+e.message);
        raise;
      end;
    end;

    s := FOrder;
    if s<>'' then begin
      S := StringReplace(FOrder, ',', ';', [rfReplaceAll]);
      S := UpperCase(S);
      i := Pos('.', S);
      while i <> 0 do begin
        for j := i downto 1 do
          if S[j] in [' ',',',';'] then break
          else S[j] := ' ';

        i := Pos('.', S);
      end;

      indexsql := 'create index i01 on '+tablename+'('+s+')';
      loctable.connection.execsql(indexsql);
    end;

    loctable.db.TableName := tablename;
    loctable.db.active := true;
    ds.first;
    try
      BlobStream := TMemoryStream.Create;
      //locdb.AutoCommit := false;
      //locdb.StartTransaction;
      try
        while not ds.eof do begin
          loctable.db.insert;
          for i := 0 to ds.fieldcount-1 do begin
            if ds.fields[i].isblob then begin
              BlobStream.SetSize(0);
              TBlobField(ds.Fields[i]).SaveToStream(BlobStream);
              tblobfield(loctable.fields[i]).loadfromstream(blobstream);
            end
            else
              loctable.db.fields[i].value := ds.fields[i].value;
          end;

          loctable.db.post;
          ds.next;
        end;

        //locdb.Commit;
      except
        //locdb.Rollback;
        raise;
      end;
    finally
      //locdb.AutoCommit := true;
      BlobStream.Free;
    end;
  finally
    freeandnil(loctable);
    freeandnil(locdb);
  end;
end;

function TBizQuery.savetofile: string;
var
  dststream: tmemorystream;
  RemoteID, FieldLen, i, j: integer;
  GetType: byte;
  RecCount, DataLen: integer;
  BlobStream: TMemorystream;
  MemoryStream: TBizMemoryStream;
  MemLen, SendLen: integer;
  C: char;
  S, filename,MemoStr: string;
  l: cardinal;
  B: boolean;
  ds: tdataset;
  d: extended;
  dt: tdatetime;
begin
  filename := 'SESS'+biztempname+'.db';
  result := bizstring(@serverparam^.tmppath[1]);
  try
    BlobStream := TMemoryStream.Create;
    MemoryStream := TbizMemoryStream.Create;

    memorystream.writestring(filename);
    MemoryStream.Writeint(self.recordcount);

    memorystream.writeint(self.FieldDefs.Count);
    for i := 0 to self.FieldDefs.Count-1 do begin
      S := UpperCase(self.FieldDefs[i].Name);
      memorystream.writestring(s);
      if self.FieldDefs[i].DataType = ftWideString then begin
        memorystream.writeint(integer(ftString));
        memorystream.writeint(self.FieldDefs[i].Size);
        memorystream.writeint(0);
      end
      else begin
        if self.FieldDefs[i].DataType in [ftBCD, ftFloat, ftCurrency] then begin
          if Copy(S,1,2)='I_' then begin
            memorystream.writeint(integer(ftInteger));
            memorystream.writeint(0);
            memorystream.writeint(0);
            self.Fields[i].Tag := 8;
          end
          else begin
            memorystream.writeint(integer(ftfloat));
            memorystream.writeint(self.getfieldprecision(self.fielddefs[i].name));
            memorystream.writeint(self.getfieldscale(self.fielddefs[i].name));
          end;
        end
        else begin
          memorystream.writeint(integer(self.FieldDefs[i].DataType));
          memorystream.writeint(self.FieldDefs[i].Size);
          memorystream.writeint(0);
        end;
      end;

      //bizloginfo(inttostr(integer(self.fielddefs[i].datatype))+',size:'+inttostr(self.FieldDefs[i].Size)
      //  +','+
    end;

    DataLen := 0;
    ds := self;
    while not ds.Eof do begin
      for i := 0 to ds.FieldCount-1 do begin
        case ds.fields[i].datatype of
          ftstring,ftwidestring,ftwidememo,ftmemo:
            begin
              memorystream.writestring(ds.fields[i].asstring);
            end;
          ftinteger,ftlargeint:
            begin
              memorystream.writeint(ds.fields[i].asinteger);
            end;
          ftBCD, ftFloat, ftCurrency:
            begin
              if ds.fields[i].tag = 8 then begin
                memorystream.writeint(ds.fields[i].asinteger);
              end
              else
              begin
                d := ds.fields[i].Asfloat;
                memorystream.writeextended(d);
              end;
            end;
          ftdatetime, fttime, ftdate:
            begin
              dt := ds.fields[i].asdatetime;
              memorystream.writedatetime(dt);
            end;
          else
            begin
              if ds.Fields[i].IsBlob then begin
                BlobStream.SetSize(0);
                TBlobField(ds.Fields[i]).SaveToStream(BlobStream);
                FieldLen := BlobStream.Size;
                MemoryStream.Writeint(FieldLen);
                MemoryStream.Writebuff(PChar(BlobStream.Memory), FieldLen);
                DataLen := DataLen+FieldLen+4;
              end
              else tbizmessage.raiseerror(fsession.lang,0, 1, 'fieldtype not found:'+inttostr(integer(ds.fields[i].datatype)));
            end;
        end;
      end;

      ds.Next;
    end;

    try
      dststream := tmemorystream.create;
      bizcompress(memorystream,dststream);
      dststream.savetofile(result+filename);
    finally
      dststream.free;
    end;

    result := filename;
  finally
    BlobStream.Free;
    MemoryStream.Free;
  end;
end;

procedure initmsg;
var
  s,s1,s2,s3,idstr,lang,msgstr: string;
  msg: tismap;
  msgid,sysid: integer;
  txtfile: tbiztextfile;
  i: integer;
  firstnum: boolean;
begin
  zhmsgmap.clear;
  trmsgmap.clear;
  enmsgmap.clear;
  frmsgmap.clear;
  dumsgmap.clear;
  jpmsgmap.clear;
  krmsgmap.clear;
  spmsgmap.clear;
  rumsgmap.clear;
  s := '/etc/ebizmis-message.txt';
  if fileexists(s) then begin
    try
      txtfile := tbiztextfile.create;
      txtfile.openexistfile(s,true);
      while not txtfile.eof do begin
        s := txtfile.readln;
        if (s='') or (copy(s,1,2)='//') or (s[1]=' ') then continue;
        i := pos(' ',s);
        firstnum := false;
        if i>0 then begin
          idstr := copy(s,1,i-1);
          msgstr := copy(s,i+1,1000);
          if idstr[1] in ['0'..'9'] then
            firstnum := true
          else if idstr[1]='$' then
            firstnum := false
          else
            continue;

          i := pos('.',idstr);
          s1 := '';
          s2 := '';
          s3 := '';
          sysid := 0;
          lang := '';
          if i>0 then begin
            s1 := copy(idstr,1,i-1);
            idstr := copy(idstr,i+1,1000);
            i := pos('.',idstr);
            if i>0 then begin
              s2 := copy(idstr,1,i-1);
              s3 := copy(idstr,i+1,1000);
            end;
          end
          else begin
            s1 := idstr;
          end;

          if s2='' then continue;
          //bizloginfo(nil,'sysid:'+s1+',msgid:'+s2+',lang');
          if firstnum then begin
            sysid := strtoint(s1);
            msgid := strtoint(s2);
            lang := s3;
          end
          else begin
            msgid := strtoint(s1);
            lang := s2;
          end;

          msgid := (sysid shl 16)+msgid;
          if lang='zh' then
            msg := zhmsgmap
          else if lang='tr' then
            msg := trmsgmap
          else if lang='en' then
            msg := enmsgmap
          else if lang='fr' then
            msg := frmsgmap
          else if lang='du' then
            msg := dumsgmap
          else if lang='jp' then
            msg := jpmsgmap
          else if lang='kr' then
            msg := krmsgmap
          else if lang='sp' then
            msg := spmsgmap
          else if lang='ru' then
            msg := rumsgmap
          else
            msg := zhmsgmap;

          msg.add(msgid,msgstr);
          //bizloginfo(nil,'addmsg: '+format('#%6.6x: ', [msgid])+' '+msgstr);
        end;
      end;
    finally
      txtfile.free;
    end;
  end;
end;

end.

