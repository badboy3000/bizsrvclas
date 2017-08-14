unit bizutils;

{$mode objfpc}{$H+}
{$define EBIZMIS}

interface

uses
  Classes, SysUtils,bizsrvclass,db,dateutils,zstream,httpprotocol,IdStrings,math,base64,
  IdHTTP,IdIOHandler, IdIOHandlerSocket, IdIOHandlerStack, IdSSL, IdSSLOpenSSL;

procedure memcopy(dest, src : pointer; size : integer);
procedure bizloginfo(p: tbizsession; msg: string);
procedure bizlogerror(p: tbizsession; msg: string);
procedure bizlogwarn(p: tbizsession; msg: string);
function bizunquote(const str: string): string;
procedure bizfill(p: pointer; len: integer; fill: char);
function bizgetwxaccesstoken(servername: string; appid: integer): string;
function bizgetwxjsticket(servername: string; appid: integer): string;
procedure bizstring(var str: string; p: pchar; len: integer=0); overload;
function bizstring(p: pchar; len: integer=0): string; overload;
procedure bizbuffer(buff: pchar; s: string);
function bizencrypt(key1, key2: integer; Buff: Pchar; Len: integer): integer;
function bizdecrypt(key1, key2: integer; Buff: Pchar; Len: integer): integer;
procedure stringtochar(const str: string; p: pchar; len: integer);
function chartostring(p: pchar; len: integer): string;
function GetSQLDateTimeText(Time: TDateTime): string;
function GetFieldSQLText(Field: TField): string;
function GetVariant(VarRec: TVarRec): variant;
function FixedLen(const s: string; Len: integer; filled: char=' '): string;
function GetFieldDefSQL(datatype: tfieldtype; fieldname: string; Fieldsize,fieldprecision: integer; div4: boolean=true): string;
function bizreadfile(const filename: string): string;
procedure bizwritefile(const filename, content: string);
function biztempint: integer;
function biztempname: string;
function bizcopyfile(const src, dest: string): boolean;
function BizFileSize(const FileName: string): int64;
function BizFileTime(const FileName: string): tdatetime;
function StandardStrToDateTime(DateTime: string): TDateTime;
function bizurlencode(const inputstr: string): string;
function bizurldecode(const inputstr: string; isfieldvalue: boolean=true): string;
procedure DelimitString(const S: string; Delimiter: Char; StringList: TStringList; RemoveHeader: boolean=False);
procedure BizCompress(vSrc, vDest: TStream);
procedure BizDecompress(vSrc, vDest: TStream);
function bizfileexists(const filename: string): boolean;
function bizformatdatetime(const FmtStr: string; DT: TDateTime): string;
function FixedIntToStr(n: integer; Len: integer=0; PadZero: boolean=False): string;
function BizRound(D: extended; Dec: integer): extended;
function bizqrencodepic(const content, destfile: string; picsize: integer): integer;
function bizuuid: string;
function BizDivide(Op1, Op2: extended): extended;
function BizHTMLEncode(const AStr: String): String;
function BizHTMLDecode(const AStr: String): String;
function BizBase64Encode(const AStr: String): String;
function BizBase64Decode(const AStr: String): String;
function bizreadfilestring(const filename: string): string;
procedure bizwritefilestring(const filename, content: string);
function bizpidexists(pid: integer): boolean;
function GetSQLText(const str: string): string;
procedure bizappendfile(seq: integer; const filename: string; data: pansichar; len: integer);
procedure bizprocessfile(filename: string; proc: TBizProcessProc);
function bizconvertfile(const srcchar,destchar: string; const srcfile,destfile: string): integer;
function getlastyear(dt: TDate): TDateTime;
function GetMonthStart(DateTime: TDateTime): TDateTime;
function GetMonthEnd(DateTime: TDateTime): TDateTime;
function GetYearStart(DateTime: TDateTime): TDateTime;
function GetYearEnd(DateTime: TDateTime): TDateTime;
function GetQuarterNumber(DateTime: TDateTime): integer;
function GetQuarterStart(DateTime: TDateTime): TDateTime;
function GetQuarterEnd(DateTime: TDateTime): TDateTime;
function IsLeafYear(Year: word): boolean;
function getweekstart(dt: TDate): tdatetime;
function getweekend(dt: TDate): tdatetime;
function getxunstart(dt: TDate): tdatetime;
function getxunend(dt: TDate): tdatetime;
function gethalfyearstart(dt: TDate): tdatetime;
function gethalfyearend(dt: TDate): tdatetime;
function getweeknumber(dt: TDate): integer;
function getlastyearweek(dt: TDate): tdate;
function getdatestr(period: integer; dt: TDateTime): string;
function ProtectedDivide(Op1, Op2: double): double;
procedure bizsendsms(sj,dx,qrm: string);
function bizmd5file(const filename: string): string;
function bizsystem(const cmdline: string): integer;
function bizdetectboard(const filename: string): integer;
function bizmd5string(const src: string): string;
function bizdecryptstr(key1, key2: integer; const str: string): string;
function bizsendwxmsg(const accesstoken,wxid,msg: string): string;
procedure bizsetstringlengthproc;
procedure bizsetlength(var s: string; len: integer);
function biznewjsonreader: pointer;
function bizjsonparse(p: pointer; const jstr: string): pointer;
function bizgetjsonvaluestring(p: pointer; const jname: string): string;
function bizgetjsonvaluestringbyindex(p: pointer; index: integer): string;
function bizgetjsonvalue(p: pointer; const jname: string): pointer;
procedure bizfreejsonreader(p: pointer);
function bizgetjsonvaluesize(p: pointer): integer;
function bizjsonisarray(p: pointer): boolean;
function bizgetjsonvaluebyindex(p: pointer; index: integer): pointer;
function bizgetsyscode: string;
function bizgetlimittext(const str: string; len: integer; taildot: boolean): string;
function bizconvertstream(const srcchar,destchar: string; srcstream, deststream: tmemorystream): integer;
function bizstreamtostring(srcstream: tstream): string;
function bizstreamtostringw(srcstream: tstream): widestring;
procedure bizstringtostream(const AString: string; AStream: TStream);
procedure bizwstringtostream(const AString: widestring; AStream: TStream);
function bizutf8tounicode(const astring: string): widestring;
function bizunicodetoutf8(const astring: widestring): string;
function BizGetHttpContentType(FileExt: string): string;
procedure bizappendline(const filename, val: string);
implementation
procedure bizappendline(const filename, val: string);
var
  filestream: tfilestream;
  mode: word;
  i,j,len: integer;
  data: pchar;
  buf: array[1..1] of char;
begin
  if not fileexists(filename) then begin
    mode := fmcreate or fmopenreadwrite;
  end
  else
    mode := fmopenreadwrite;

  j := 0;
  len := length(val);
  data := pchar(val);
  buf[1] := chr($a);
  try
    filestream := tfilestream.Create(filename, mode);
    filestream.Seek(0,soFromEnd);
    while true do begin
      i := filestream.Write((data+j)^, len-j);
      j := j+i;
      if j>=len then break;
    end;
    filestream.write(buf,1);
  finally
    filestream.free;
  end;
end;

function bizutf8tounicode(const astring: string): widestring;
var
  file1,file2: string;
  buf: array[1..1024] of byte;
  i,j,k,curr: integer;
  w: widechar;
  filestream: tfilestream;
begin
  result := '';
  file1 := bizstring(@serverparam^.tmppath[1],0)+biztempname;
  file2 := bizstring(@serverparam^.tmppath[1],0)+biztempname;
  bizwritefile(file1,astring);
  bizconvertfile('utf-8','unicode', file1, file2);
  try
    filestream := tfilestream.create(file2,fmopenread);
    i:=0;
    j := 0;
    result := '';
    while filestream.position<filestream.size do begin
      i := filestream.read(buf,1024);
      if (j=0) and (buf[1]=$ff) and (buf[2]=$fe) then begin
        curr := 3;
      end
      else curr := 1;

      inc(j);
      i := (i div 2)*2;
      k := curr;
      while k<i do begin
        w := widechar((buf[k+1] shl 8)+buf[k]);
        k := k+2;
        result := result+w;
      end;
    end;
  finally
    filestream.free;
  end;

  deletefile(file1);
  deletefile(file2);
end;

function bizunicodetoutf8(const astring: widestring): string;
var
  file1,file2: string;
  buf: array[1..1024] of byte;
  i,j,k,curr: integer;
  w: widechar;
  filestream: tfilestream;
begin
  result := '';
  file1 := bizstring(@serverparam^.tmppath[1],0)+biztempname;
  file2 := bizstring(@serverparam^.tmppath[1],0)+biztempname;
  try
    filestream := tfilestream.create(file1,fmCreate or fmopenreadwrite);
    buf[1] := $ff;
    buf[2] := $fe;
    filestream.Write(buf,2);
    for i := 1 to length(astring) do begin
      w := astring[i];
      filestream.Writeword(word(w));
    end;
  finally
    filestream.free;
  end;

  bizconvertfile('unicode', 'utf-8', file1, file2);
  if not fileexists(file2) then exit;
  try
    filestream := tfilestream.create(file2,fmopenread);
    i:=0;
    j := 0;
    result := '';
    while filestream.position<filestream.size do begin
      i := filestream.read(buf,1024);
      k := 1;
      while k<=i do begin
        result := result+chr(buf[k]);
        inc(k);
      end;
    end;
  finally
    filestream.free;
  end;

  deletefile(file1);
  deletefile(file2);
end;

procedure bizstringtostream(const AString: string; AStream: TStream);
var
  SS: TStringStream;
begin
  SS := TStringStream.Create(AString);
  try
    SS.Position := 0;
    AStream.CopyFrom(SS, SS.Size);
  finally
    SS.Free;
  end;
end;

function bizstreamtostring(srcstream: tstream): string;
var
  SS: TStringStream;
begin
  if srcStream <> nil then
  begin
    SS := TStringStream.Create('');
    try
      SS.CopyFrom(srcStream, 0);
      Result := SS.DataString;
    finally
      SS.Free;
    end;
  end else
  begin
    Result := '';
  end;
end;

procedure bizwstringtostream(const AString: widestring; AStream: TStream);
begin

end;

function bizstreamtostringw(srcstream: tstream): widestring;
var
  SS: TStringStream;
begin
  if srcStream <> nil then
  begin
    SS := TStringStream.Create('');
    try
      SS.CopyFrom(srcStream, 0);
      Result := SS.DataString;
    finally
      SS.Free;
    end;
  end else
  begin
    Result := '';
  end;
end;

function bizgetlimittext(const str: string; len: integer; taildot: boolean): string;
var
  currlen,i,j: integer;
  s,s1: string;
  findnext: boolean;
  stream1,stream2: tmemorystream;
  w,w1: widestring;
begin
  currlen := 0;
  i := 0;
  result := '';
  w := bizutf8tounicode(str);
  j := length(w);
  findnext := false;
  w1 := '';
  while true do begin
    if currlen>=len then break;
    if i>=j then break;
    inc(i);
    if (w[i]<>'>') and (findnext) then continue;
    if (w[i]='>') and (findnext) then begin
      findnext := false;
      continue;
    end;

    if w[i]='<' then begin
      findnext := true;
      continue;
    end;

    w1 := w1+w[i];
    inc(currlen);
  end;

  if i<j then findnext := true
  else findnext := false;

  if taildot then begin
    if findnext then begin
      result := bizunicodetoutf8(w1+'...');
    end
    else
      result := bizunicodetoutf8(w1);
  end
  else
    result := bizunicodetoutf8(w1);
end;

function locgetsyscode(p: pchar): integer; cdecl; external 'bizutils' name 'bizgetrealmcode';
function bizgetsyscode: string;
var
  s: string;
begin
  s := '';
  setlength(s,6);
  locgetsyscode(pchar(s));
  result := s;
end;

function locjsonisarray(p: pointer): integer; cdecl; external 'bizutils' name 'bizjsonisarray';
function bizjsonisarray(p: pointer): boolean;
var
  i: integer;
begin
  i := locjsonisarray(p);
  if i=1 then result := true
  else result := false;
end;

function locgetjsonvaluesize(p: pointer): integer; cdecl; external 'bizutils' name 'bizgetjsonvaluesize';
function bizgetjsonvaluesize(p: pointer): integer;
begin
  result := locgetjsonvaluesize(p);
end;

function locgetjsonvaluebyindex(p: pointer; index: integer): pointer; cdecl; external 'bizutils' name 'bizgetjsonvaluebyindex';
function bizgetjsonvaluebyindex(p: pointer; index: integer): pointer;
begin
  result := locgetjsonvaluebyindex(p,index);
end;


function locgetjsonvalue(p: pointer; pstr: pchar): pointer; cdecl; external 'bizutils' name 'bizgetjsonvalue';
function bizgetjsonvalue(p: pointer; const jname: string): pointer;
begin
  result := locgetjsonvalue(p,pchar(jname));
end;

procedure locgetjsonvaluestringbyindex(p: pointer; index: integer; pres: pointer); cdecl; external 'bizutils' name 'bizgetjsonvaluestringbyindex';
function bizgetjsonvaluestringbyindex(p: pointer; index: integer): string;
begin
  result := '';
  locgetjsonvaluestringbyindex(p, index, @result);
end;

procedure locgetjsonvaluestring(p: pointer; pstr: pchar; pres: pointer); cdecl; external 'bizutils' name 'bizgetjsonvaluestring';
function bizgetjsonvaluestring(p: pointer; const jname: string): string;
begin
  result := '';
  locgetjsonvaluestring(p, pchar(jname), @result);
end;

function locnewjsonreader: pointer; cdecl; external 'bizutils' name 'biznewjsonreader';
function biznewjsonreader: pointer;
begin
  result := locnewjsonreader;
end;

function locjsonparse(p: pointer; pstr: pchar): pointer; cdecl; external 'bizutils' name 'bizjsonparse';
function bizjsonparse(p: pointer; const jstr: string): pointer;
begin
  result := locjsonparse(p, pchar(jstr));
end;

procedure bizfreejsonreader(p: pointer);
begin
end;

procedure locsetlength(p: pointer; len: integer); cdecl; external 'bizutils' name 'bizsetlength';
procedure bizsetlength(var s: string; len: integer);
begin
  locsetlength(@s,len);
end;

procedure cppsetstringlength(p: pointer; len: integer); cdecl;
begin
  setlength(pstring(p)^, len);
end;

procedure locsetstringlengthproc(p: pointer); cdecl; external 'bizutils' name 'bizsetstringlengthproc';
procedure bizsetstringlengthproc;
begin
  locsetstringlengthproc(@cppsetstringlength);
end;

function locdecryptstr(key1, key2: integer; Buff: Pchar; Len: integer): integer; cdecl; external 'bizutils' name 'bizdecryptstr';
function bizdecryptstr(key1, key2: integer; const str: string): string;
var
  s: string;
  i: integer;
begin
  s := str;
  i := length(s);
  i := locdecryptstr(key1,key2,pchar(s),i);
  result := bizstring(pchar(s));
end;

function locdetectboard(p: pchar): integer; cdecl; external 'bizutils' name 'bizdetectboard';
function bizdetectboard(const filename: string): integer;
begin
  result := locdetectboard(pchar(filename));
end;

function locsystem(p: pchar): integer; cdecl; external 'bizutils' name 'bizsystem';
function bizsystem(const cmdline: string): integer;
begin
  result := locsystem(pchar(cmdline));
end;

procedure locmd5pchar(filename, outstr: pchar; outlen: integer); cdecl; external 'bizutils' name 'bizmd5pchar';
function bizmd5string(const src: string): string;
var
  buf: array[1..128] of char;
begin
  locmd5pchar(pchar(src),@buf[1],128);
  bizstring(result,@buf[1],128);
end;

procedure locmd5file(filename, outstr: pchar; outlen: integer); cdecl; external 'bizutils' name 'bizmd5file';
function bizmd5file(const filename: string): string;
var
  buf: array[1..128] of char;
begin
  locmd5file(pchar(filename), @buf[1], 128);
  bizstring(result, @buf[1], 128);
end;

procedure bizsendsms(sj,dx,qrm: string);
var
  s: string;
  idhttp1: tidhttp;
  smskey: string;
begin
{$ifdef EBIZMIS}
{$include '../inc/mykey.txt'}
{$else}
  smskey := '1234';
{$endif}
  s := 'http://utf8.sms.webchinese.cn/?'+smskey+'&smsMob='+sj+'&smsText='+bizurlencode(dx);
  try
    idhttp1 := tidhttp.create(nil);
    idhttp1.get(s);
  finally
    idhttp1.free;
  end;
end;

function ProtectedDivide(Op1, Op2: double): double;
begin
  if Op2 = 0 then
    Result := 0
  else
    Result := Op1/Op2;
end;

function getdatestr(period: integer; dt: TDateTime): string;
var
  y,m,d: word;
  i: integer;
  dt1: tdate;
begin
  result := '';
  case period of
    0:
      begin
        result := FormatDateTime('yyyy-mm-dd',dt);
      end;
    1:
      begin
        DecodeDate(dt,y,m,d);
        dt1 := getweekend(dt);
        i := getweeknumber(dt);
        if (i=1) and (m=12) then
          result := IntToStr(y+1)+'年第'+inttostr(i)+'周'+#$a+'('+formatdatetime('mm.dd',dt)+'-'+formatdatetime('mm.dd',dt1)+')'
        else
          result := IntToStr(y)+'年第'+inttostr(i)+'周'+#$a+'('+formatdatetime('mm.dd',dt)+'-'+formatdatetime('mm.dd',dt1)+')';
      end;
    2:
      begin
        dt1 := getxunstart(dt);
        DecodeDate(dt1,y,m,d);
        if d=1 then result := IntToStr(y)+'年'+inttostr(m)+'月上旬'
        else if d=11 then result := IntToStr(y)+'年'+inttostr(m)+'月中旬'
        else result := IntToStr(y)+'年'+inttostr(m)+'月下旬';
      end;
    3:
      begin
        DecodeDate(dt,y,m,d);
        result := IntToStr(y)+'年'+inttostr(m)+'月';
      end;
    4:
      begin
        DecodeDate(dt,y,m,d);
        if m=1 then
          result := IntToStr(y)+'年一季度'
        else if m=4 then
          result := IntToStr(y)+'年二季度'
        else if m=7 then
          result := IntToStr(y)+'年三季度'
        else
          result := IntToStr(y)+'年四季度';
      end;
    5:
      begin
        DecodeDate(dt,y,m,d);
        if m=1 then
          result := IntToStr(y)+'年上半年'
        else
          result := IntToStr(y)+'年下半年';
      end;
    6:
      begin
        DecodeDate(dt,y,m,d);
        result := IntToStr(y)+'年';
      end;
  end;
end;

function getlastyearweek(dt: TDate): tdate;
var
  y,m,d: word;
  rq: tdate;
  i: integer;
begin
  DecodeDate(dt,y,m,d);
  rq := getweekstart(EncodeDate(y,1,1));
  i := Floor(dt-rq)+1;
  i := ((i-1) div 7)+1;

  rq := getweekstart(EncodeDate(y-1,1,1));
  result := rq+(i-1)*7;
end;

function getweeknumber(dt: TDate): integer;
var
  y,y1,m,d: word;
  rq: tdate;
  i: integer;
  dt1: tdate;
begin
  DecodeDate(dt,y,m,d);
  if (m=12) and (d>25) then begin
    decodedate(getweekend(dt),y,m,d);
    if y1<>y then begin
      result := 1;
      exit;
    end;
  end;

  rq := getweekstart(EncodeDate(y,1,1));
  i := Floor(dt-rq)+1;
  result := ((i-1) div 7)+1;
end;


function getxunstart(dt: TDate): tdatetime;
var
  y,m,d: word;
begin
  DecodeDate(dt,y,m,d);
  if d<=10 then d := 1
  else if d<=20 then d := 11
  else d := 21;
  result := EncodeDate(y,m,d);
end;

function getxunend(dt: TDate): tdatetime;
var
  y,m,d: word;
begin
  DecodeDate(dt,y,m,d);
  if d<=10 then begin
    result := EncodeDate(y,m,10)+encodetime(23,59,59,999);
  end
  else if d<=20 then begin
    result := EncodeDate(y,m,20)+encodetime(23,59,59,999);
  end
  else begin
    result := getmonthend(dt);
  end;
end;

function gethalfyearstart(dt: TDate): tdatetime;
var
  y,m,d: word;
begin
  DecodeDate(dt,y,m,d);
  if m<=6 then result := EncodeDate(y,1,1)
  else result := EncodeDate(y,7,1);
end;

function gethalfyearend(dt: TDate): tdatetime;
var
  y,m,d: word;
begin
  DecodeDate(dt,y,m,d);
  if m<=6 then result := EncodeDate(y,6,30)
  else result := EncodeDate(y,12,31)+encodetime(23,59,59,999);
end;


function getweekend(dt: TDate): tdatetime;
var
  i: integer;
begin
  result := getweekstart(dt+7)-1+encodetime(23,59,59,999);
end;

function getweekstart(dt: TDate): tdatetime;
var
  i: integer;
begin
  i := dayofweek(dt);
  if i=1 then result := Floor(dt-6)
  else result := Floor(dt-i+2);
end;


function getlastyear(dt: TDate): TDateTime;
var
  y,m,d: word;
begin
  DecodeDate(dt,y,m,d);
  try
    result := EncodeDate(y-1,m,d);
  except
    result := Floor(getmonthend(EncodeDate(y-1,m,1)));
  end;
end;

function GetMonthStart(DateTime: TDateTime): TDateTime;
var
  Year: word;
  Month: word;
  Day: word;
begin
  DecodeDate(DateTime, Year, Month, Day);
  Result := EncodeDate(Year, Month, 1);
end;

function GetMonthEnd(DateTime: TDateTime): TDateTime;
var
  Year: word;
  Month: word;
  Day: word;
begin
  DecodeDate(DateTime, Year, Month, Day);
  if Month = 2 then
    if IsLeafYear(Year) then Day := 29
    else Day := 28
  else if (Month = 1) or (Month = 3) or(Month = 5) or(Month = 7) or(Month = 8) or(Month = 10) or(Month = 12) then Day := 31
  else Day := 30;

  Result := EncodeDate(Year, Month, Day)+EncodeTime(23, 59, 59, 999);
end;

function GetQuarterNumber(DateTime: TDateTime): integer;
var
  Year, Month, Day: Word;
begin
  if DateTime = 1 then exit;
  DecodeDate(DateTime, Year, Month, Day);
  case Month of
    1, 2, 3: Result := 1;
    4, 5, 6: Result := 2;
    7, 8, 9: Result := 3;
    10, 11, 12: Result := 4;
  end;
end;

function GetQuarterStart(DateTime: TDateTime): TDateTime;
var
  Year, Month, Day: Word;
begin
  DecodeDate(DateTime, Year, Month, Day);
  case GetQuarterNumber(DateTime) of
    1: Result := EncodeDate(Year, 1, 1);
    2: Result := EncodeDate(Year, 4, 1);
    3: Result := EncodeDate(Year, 7, 1);
    4: Result := EncodeDate(Year, 10, 1);
  end;
end;

function GetQuarterEnd(DateTime: TDateTime): TDateTime;
var
  Year, Month, Day: Word;
begin
  DecodeDate(DateTime, Year, Month, Day);
  case GetQuarterNumber(DateTime) of
    1: Result := EncodeDate(Year, 3, 31);
    2: Result := EncodeDate(Year, 6, 30);
    3: Result := EncodeDate(Year, 9, 30);
    4: Result := EncodeDate(Year, 12, 31);
  end;

  Result := Result+EncodeTime(23, 59, 59, 999);
end;

function IsLeafYear(Year: word): boolean;
begin
  if Year mod 400 = 0 then
  begin
    Result := True;
    exit;
  end;

  if (Year mod 100 = 0) and (Year mod 400 <> 0) then
  begin
    Result := False;
    exit;
  end;

  if Year mod 4 = 0 then
  begin
    Result := True;
    exit;
  end;

  Result := False;
end;

function GetYearStart(DateTime: TDateTime): TDateTime;
var
  Year: word;
  Month: word;
  Day: word;
begin
  DecodeDate(DateTime, Year, Month, Day);
  Result := EncodeDate(Year, 1, 1);
end;

function GetYearEnd(DateTime: TDateTime): TDateTime;
var
  Year: word;
  Month: word;
  Day: word;
begin
  DecodeDate(DateTime, Year, Month, Day);
  Result := EncodeDate(Year, 12, 31)+EncodeTime(23, 59, 59, 999);
end;


function convertfile(srcchar, destchar, srcfile, destfile: pchar): integer; cdecl; external 'bizutils' name 'bizconvertfile';
function bizconvertfile(const srcchar,destchar: string; const srcfile,destfile: string): integer;
begin
  result := convertfile(pchar(srcchar),pchar(destchar),pchar(srcfile), pchar(destfile));
end;

function bizconvertstream(const srcchar,destchar: string; srcstream, deststream: tmemorystream): integer;
var
  file1,file2: string;
begin
  file1 := bizstring(@serverparam^.tmppath[1],0)+biztempname;
  srcstream.savetofile(file1);
  file2 := bizstring(@serverparam^.tmppath[1],0)+biztempname;
  result := convertfile(pchar(srcchar),pchar(destchar),pchar(file1), pchar(file2));
  deststream.loadfromfile(file2);
  deletefile(file1);
  deletefile(file2);
end;

procedure processfile(filename: pchar;proc: TBizProcessProc); cdecl; external 'bizutils' name 'bizprocessfile';
procedure bizprocessfile(filename: string; proc: TBizProcessProc);
begin
  processfile(pchar(filename), proc);
end;

procedure bizappendfile(seq: integer; const filename: string; data: pansichar; len: integer);
var
  filestream: tfilestream;
  mode: word;
  i,j: integer;
begin
  if seq=1 then begin
    deletefile(filename);
    mode := fmcreate or fmopenreadwrite;
  end
  else
    mode := fmopenreadwrite;

  j := 0;
  try
    filestream := tfilestream.Create(filename, mode);
    filestream.Seek(0,soFromEnd);
    while true do begin
      i := filestream.Write((data+j)^, len-j);
      j := j+i;
      if j>=len then break;
    end;
  finally
    filestream.free;
  end;
end;

function GetSQLText(const str: string): string;
begin
  result := ''''+stringreplace(str,'''','''''',[rfreplaceall])+'''';
end;

function pidexists(pid: integer): boolean; cdecl; external 'bizutils' name 'bizpidexists';
function bizpidexists(pid: integer): boolean;
begin
  result := pidexists(pid);
end;

function bizreadfilestring(const filename: string): string;
var
  locfile: tbiztextfile;
begin
  result := '';
  if not fileexists(filename) then exit;

  try
    locfile := tbiztextfile.create;
    locfile.openexistfile(filename,true);
    while not locfile.eof do
      if result='' then
        result := locfile.readln
      else
        result := result+#$a+locfile.readln;
  finally
    locfile.Free;
  end;
end;

procedure bizwritefilestring(const filename, content: string);
var
  locfile: tbiztextfile;
begin
  deletefile(filename);
  try
    locfile := tbiztextfile.create;
    locfile.createnewfile(filename);
    locfile.writestring(content);
  finally
    locfile.Free;
  end;
end;

type
{ TBogusStream }

TBogusStream = class(TStream)
 protected
  FData: string;
  function GetSize: Int64; override;
 public
  function Read(var Buffer; Count: Longint): Longint; override;
  function Write(const Buffer; Count: Longint): Longint; override;
  function Seek(Offset: Longint; Origin: Word): Longint; overload; override;
  function Seek(const Offset: Int64; Origin: TSeekOrigin): Int64; overload; override;
  procedure Reset;
end;

  { TBogusStream }

function TBogusStream.GetSize: Int64;
begin
  Result := Length(FData);
end;

function TBogusStream.Read(var Buffer; Count: Longint): Longint;
begin
  Result := Min(Count, Length(FData));

  Move(FData[1], Buffer, Result);
  Delete(FData, 1, Result);
end;

function TBogusStream.Write(const Buffer; Count: Longint): Longint;
var
  l: Integer;
begin
  l := Length(FData);
  Result := Count;
  SetLength(FData, l + Count);
  Inc(l);
  Move(Buffer, FData[l], Count);
end;

function TBogusStream.Seek(Offset: Longint; Origin: Word): Longint;
begin
  Result := Offset;
end;

function TBogusStream.Seek(const Offset: Int64; Origin: TSeekOrigin): Int64;
begin
  Result := Offset;
end;

procedure TBogusStream.Reset;
begin
  FData := '';
end;

function BizHTMLEncode(const AStr: String): String;
begin
  result := strhtmlEncode(astr);
end;

function BizHTMLDecode(const AStr: String): String;
begin
  result := strhtmlDecode(astr);
end;

function BizBase64Encode(const AStr: String): String;
var
  Dummy: TBogusStream;
  Enc: TBase64EncodingStream;
begin
  Result := '';
  if Length(AStr) = 0 then
    Exit;

  Dummy := TBogusStream.Create;
  Enc := TBase64EncodingStream.Create(Dummy);

  Enc.Write(astr[1], Length(astr));
  Enc.Free;
  SetLength(Result, Dummy.Size);
  Dummy.Read(Result[1], Dummy.Size);

  Dummy.Free;
end;

function BizBase64Decode(const AStr: String): String;
var
  Dummy: TBogusStream;
  Enc: TBase64DecodingStream;
begin
  Result := '';
  if Length(AStr) = 0 then
    Exit;

  Dummy := TBogusStream.Create;
  Enc := TBase64DecodingStream.Create(Dummy);

  Enc.Write(astr[1], Length(astr));
  Enc.Free;
  SetLength(Result, Dummy.Size);
  Dummy.Read(Result[1], Dummy.Size);

  Dummy.Free;
end;

function BizDivide(Op1, Op2: extended): extended;
begin
  if Op2 = 0 then
    Result := 0
  else
    Result := Op1/Op2;
end;

function getuuid(uuid: pchar; buflen: integer): integer; cdecl; external 'bizutils' name 'bizgetuuid';
function bizuuid: string;
var
  buf: array[1..200] of char;
begin
  getuuid(@buf[1], 200);
  result := bizstring(@buf[1],200);
end;

function qrencode(content, destfile: pchar; picsize: integer): integer; cdecl; external 'bizutils' name 'bizqrencode';
function bizqrencodepic(const content, destfile: string; picsize: integer): integer;
begin
  //bizloginfo(nil,content+','+destfile);
  result := qrencode(pchar(content), pchar(destfile), picsize);
  //bizloginfo(nil,inttostr(result));
end;

function BizRound(D: extended; Dec: integer): extended;
var
  I,j: Integer;
  C: Extended;
  s: string;
begin
  if dec>=0 then begin
    j := 1;
    for I := 1 to Dec do    // Iterate
      j := j*10;

    c := d*j;
    if (frac(c)-0.5)>=0 then
      c := trunc(c)+1
    else
      c := trunc(c);
    {
    s := floattostr(c);
    i := pos('.',s);
    if i>0 then begin
      if c>0 then begin
        if s[i+1] in ['5'..'9'] then
          c := strtofloat(copy(s,1,i-1))+1
        else
          c := strtofloat(copy(s,1,i-1));
      end
      else if c<0 then begin
        if s[i+1] in ['5'..'9'] then
          c := strtofloat(copy(s,1,i-1))-1
        else
          c := strtofloat(copy(s,1,i-1));
      end;
    end;
    }
    Result := c/j;
  end
  else begin
    j := 1;
    for I := 1 to -1*Dec do    // Iterate
      j := j*10;

    c := bizround(d/j,0);
    result := c*j;
  end;
end;

function FixedIntToStr(n: integer; Len: integer=0; PadZero: boolean=False): string;
var
  I: Integer;
begin
  if Len<=0 then Len := 10;
  Result := Format('%'+IntToStr(Len)+'.'+IntToStr(Len)+'d', [n]);
  if PadZero then exit;
  for I := 1 to Length(Result) do    // Iterate
  begin
    if Result[i]<>'0' then exit
    else Result[i] := ' ';
  end;    // for
end;

function bizformatdatetime(const FmtStr: string; DT: TDateTime): string;
var
  Year, Month, Day, Hour, Minute, Sec, Minisec: word;
  sYear, sMonth, sDay, sHour, sMinute, sSec: string;
begin
  if DT<=1 then begin
    Result := '';
    exit;
  end;

  DecodeDate(DT, Year, Month, Day);
  DecodeTime(Dt, Hour, Minute, Sec, MiniSec);
  sYear := FixedIntToStr(Year, 4, True);
  sMonth := FixedIntToStr(Month, 2, True);
  sDay := FixedIntToStr(Day, 2, True);
  sHour := FixedIntToStr(Hour, 2, True);
  sMinute := FixedIntToStr(Minute, 2, True);
  sSec := FixedIntToStr(Sec, 2, True);
  Result := FmtStr;
  Result := StringReplace(Result, 'yyyy', sYear, [rfReplaceAll]);
  Result := StringReplace(Result, 'yy', FixedIntToStr(Year-2000,2,True), [rfReplaceAll]);
  Result := StringReplace(Result, 'mm', sMonth, [rfReplaceAll]);
  Result := StringReplace(Result, 'dd', sDay, [rfReplaceAll]);
  //if (hour=0) and (minute=0) then begin
  //  Result := StringReplace(Result, ' hh时nn分', '', [rfReplaceAll]);
  //  Result := StringReplace(Result, ' hh时nn分ss秒', '', [rfReplaceAll]);
  //  Result := StringReplace(Result, ' h时n分', '', [rfReplaceAll]);
  //  Result := StringReplace(Result, ' h时n分s秒', '', [rfReplaceAll]);
  //  Result := StringReplace(Result, ' hh:nn', '', [rfReplaceAll]);
  //  Result := StringReplace(Result, ' hh:nn:ss', '', [rfReplaceAll]);
  //  Result := StringReplace(Result, ' h:n', '', [rfReplaceAll]);
  //  Result := StringReplace(Result, ' h:n:s', '', [rfReplaceAll]);
  //end
  //else begin
    Result := StringReplace(Result, 'hh', sHour, [rfReplaceAll]);
    Result := StringReplace(Result, 'nn', sMinute, [rfReplaceAll]);
    Result := StringReplace(Result, 'ss', sSec, [rfReplaceAll]);
    Result := StringReplace(Result, 'h:', inttostr(hour)+':', [rfReplaceAll]);
    Result := StringReplace(Result, 'n:', inttostr(Minute)+':', [rfReplaceAll]);
    Result := StringReplace(Result, 's:', inttostr(Sec)+':', [rfReplaceAll]);
    Result := StringReplace(Result, 'h时', inttostr(hour)+'时', [rfReplaceAll]);
    Result := StringReplace(Result, 'n分', inttostr(Minute)+'分', [rfReplaceAll]);
    Result := StringReplace(Result, 's秒', inttostr(Sec)+'秒', [rfReplaceAll]);
  //end;

  Result := StringReplace(Result, 'm', inttostr(month), [rfReplaceAll]);
  Result := StringReplace(Result, 'd', inttostr(day), [rfReplaceAll]);
end;

procedure BizCompress(vSrc, vDest: TStream);
var
  B: array[1..2048] of byte;
  R: Integer;
  vCompressor: TStream;  // compression stream
begin
  vsrc.position := 0;
  if vsrc.size<=0 then exit;
  try
    vCompressor := TCompressionStream.Create(clMax, vDest);
    repeat
      R := vSrc.Read(B, 2048);
      if R > 0 then
        vCompressor.Write(B, R);
    until R < 2048;
  finally
    vCompressor.Free;
  end;

  vdest.Position := 0;
end;

procedure BizDecompress(vSrc, vDest: TStream);
var
  B: array[1..2048] of byte;
  R: Integer;
  vDecompressor: TStream;  // compression stream
begin
  vsrc.position := 0;
  if vsrc.size<=0 then exit;
  try
    vDecompressor := TDecompressionStream.Create(vSrc);
    repeat
      R := vDecompressor.Read(B, 2048);
      if R > 0 then
        vDest.Write(B, R);
    until R < 2048;
  finally
    vDecompressor.Free;
  end;

  vdest.Position := 0;
end;

procedure DelimitString(const S: string; Delimiter: Char; StringList: TStringList; RemoveHeader: boolean=False);
var
	PStart, PEnd: PChar;
  SubS: string;
  i: integer;
begin
  StringList.Duplicates := dupAccept;
	StringList.Clear;
  if s='' then exit;
	PStart := PChar(S);
  if RemoveHeader then begin
    for i := 1 to Length(S) do
      if S[i] = Delimiter then begin
        PStart := PStart+1;
        break;
      end
      else break;
  end;

	while True do
  begin
    PEnd := StrScan(PStart, Delimiter);
    if PEnd = nil then
    begin
    	SetString(SubS, PStart, StrLen(PStart));
      SubS := Trim(SubS);
      StringList.Add(SubS);
      break;
    end
    else
    begin
	    SetString(SubS, PStart, PEnd - PStart);
      PStart := PEnd + 1;
      SubS := Trim(SubS);
      StringList.Add(SubS);
      if Delimiter = ' ' then
      	while PStart^ = ' ' do
        	PStart := PStart+1;
    end;
  end;
end;

function bizurlencode(const inputstr: string): string;
var
  i: integer;
  c: char;
begin
  result := '';
  for i := 1 to length(inputstr) do begin
    c := inputstr[i];
    if (c in ['a'..'z','A'..'Z','0'..'9']) or (c='-') or (c = '_') or (c = '.') or (c= '~') then
      result := result+c
    else
      result := result+'%'+format('%0:-2.2x',[ord(c)]);
  end;
end;

function bizurldecode(const inputstr: string; isfieldvalue: boolean=true): string;
var
  c: char;
  haspert: boolean;
  i,j: integer;
  s: string;
begin
  result := '';
  haspert := false;
  for i := 1 to length(inputstr) do begin
    c := inputstr[i];
    if c='%' then begin
      haspert := true;
      j := 0;
      s := '';
    end
    else begin
      if haspert then begin
        inc(j);
        if j<=2 then begin
          if c in ['0'..'9','A'..'F','a'..'f'] then
            s := s+c;

          if j=2 then begin
            c := chr(strtoint('$'+s));
            result := result+c;
            haspert := false;
          end;
        end;
      end
      else begin
        if (c='+') and (isfieldvalue) then result := result+' '
        else result := result+c;
        //result := result+c;
      end;
    end;
  end;
end;

function StandardStrToDateTime(DateTime: string): TDateTime;
var
  Year, Month, Day, Hour, Minute, Second,msec: word;
  s1,s2: string;
  i: integer;
  str: tstringlist;
  datestr,timestr: string;
begin
  i := pos('.',datetime);
  if i>=10 then begin
    msec := strtoint(copy(datetime,i+1,4));
    datetime := copy(datetime,1,i-1);
  end
  else begin
    msec := 0;
    datetime := stringreplace(datetime,'.','-',[rfreplaceall]);
    datetime := stringreplace(datetime,'/','-',[rfreplaceall]);
  end;

  if DateTime = '' then begin
    Result := 0;
    exit;
  end
  else begin
    if length(datetime)>19 then datetime := copy(datetime,1,19);
    if (length(datetime)=16) and (pos('-',datetime)=0) then begin
      datestr := copy(datetime,1,8);
      timestr := copy(datetime,9,8);
    end
    else if (length(datetime)=14) and (pos('-',datetime)=0) then begin
      year := strtoint(copy(datetime,1,4));
      month := strtoint(copy(datetime,5,2));
      day := strtoint(copy(datetime,7,2));
      hour := strtoint(copy(datetime,9,2));
      minute := strtoint(copy(datetime,11,2));
      second := strtoint(copy(datetime,13,2));
      result := encodedate(year,month,day)+encodetime(hour,minute,second,0);
      exit;
    end
    else if (length(datetime)=12) and (pos('-',datetime)=0) then begin
      year := strtoint(copy(datetime,1,4));
      month := strtoint(copy(datetime,5,2));
      day := strtoint(copy(datetime,7,2));
      hour := strtoint(copy(datetime,9,2));
      minute := strtoint(copy(datetime,11,2));
      result := encodedate(year,month,day)+encodetime(hour,minute,0,0);
      exit;
    end
    else begin
      i := pos(' ',datetime);
      if i>0 then begin
        datestr := copy(datetime,1,i-1);
        datestr := stringreplace(datestr,':','-',[rfreplaceall]);
        timestr := copy(datetime,i+1,200);
      end
      else begin
        datestr := datetime;
        timestr := '';
      end;
    end;

    if timestr<>'' then datetime := datestr+' '+timestr
    else datetime := datestr;
    try
      str := tstringlist.create;
      i := pos('-',datetime);
      if i>0 then begin
        delimitstring(datestr,'-',str);
        year := strtoint(str[0]);
        month := strtoint(str[1]);
        day := strtoint(str[2]);
      end
      else begin
        year := strtoint(copy(datestr,1,4));
        month := strtoint(copy(datestr,5,2));
        day := strtoint(copy(datestr,7,2));
      end;

      i := pos(':',timestr);
      if i>0 then begin
        delimitstring(timestr,':',str);
        hour := strtoint(str[0]);
        if str.count>1 then
          minute := strtoint(str[1])
        else
          Minute := 0;

        if str.Count>2 then
          second := strtoint(str[2])
        else
          second := 0;
      end
      else timestr := '';
    finally
      str.free;
    end;

    result := encodedate(year,month,day);
    if timestr='' then exit;
  end;

  result := result+encodetime(hour,minute,second,msec);
end;

function locfiletime(src: pchar): int64; cdecl; external 'bizutils' name 'bizfiletime';
function BizFiletime(const FileName: string): tdatetime;
begin
  Result := unixtodatetime(locfiletime(pchar(FileName)));
end;

function locfilesize(src: pchar): int64; cdecl; external 'bizutils' name 'bizfilesize';
function BizFileSize(const FileName: string): int64;
begin
  Result := locfilesize(pchar(FileName));
end;

function loccopyfile(src, dest: pchar): integer; cdecl; external 'bizutils' name 'bizcopyfile';
function bizcopyfile(const src, dest: string): boolean;
var
  i:integer;
begin
  i := loccopyfile(pchar(src),pchar(dest));
  if i=1 then result := true
  else result := false;
end;

function bizreadfile(const filename: string): string;
var
  locfile: tbiztextfile;
begin
  result := '';
  if not fileexists(filename) then exit;

  try
    locfile := tbiztextfile.create;
    locfile.openexistfile(filename,true);
    result := locfile.readln;
  finally
    locfile.Free;
  end;
end;

procedure bizwritefile(const filename, content: string);
var
  locfile: tbiztextfile;
begin
  try
    locfile := tbiztextfile.create;
    locfile.createnewfile(filename);
    locfile.write(content);
  finally
    locfile.Free;
  end;
end;

function BizTempName: string;
begin
  Result := 'ETMP'+IntToStr(BizTempInt);
end;

function biztempint: integer;
var
  lock: tbizlock;
  s,s1: string;
  i: integer;
begin
  s := bizstring(@serverparam^.servername[1],0);
  s1 := bizstring(@serverparam^.tmppath[1],0)+s+'-SEQ';
  try
    lock := tbizlock.create(s+'-MSG');
    s := bizreadfile(s1);
    if s1='' then i := 1
    else begin
      try
        i := strtoint(s);
        inc(i);
      except
        i := 1;
      end;
    end;

    bizwritefile(s1,inttostr(i));
    result := i;
  finally
    lock.free;
  end;
end;

function FixedLen(const s: string; Len: integer; filled: char=' '): string;
var
  I,actlen: Integer;
  hzchar,rst: ansistring;
begin
  //hzchar := bizunicodetogbk(s);
  rst := Copy(s, 1, Len);
  for I := Length(rst)+1 to Len do    // Iterate
  begin
    Rst := Rst+filled;
  end;    // for

  result := rst;
end;

function GetVariant(VarRec: TVarRec): variant;
begin
  with VarRec do
    case VType of
      vtInteger:    Result := VInteger;
      vtBoolean:    Result := VBoolean;
      vtChar:       Result := VChar;
      vtExtended:   Result := VExtended^;

      vtString:     Result := VString^;
      vtPChar:      Result := VPChar^;
      //vtObject:     Result := VObject;
      //vtClass:      Result := VClass;
      vtAnsiString: Result := string(VAnsiString);
      vtCurrency:   Result := VCurrency^;
      vtVariant:    Result := string(VVariant^);
      vtInt64:      Result := IntToStr(VInt64^);
    end;
end;

function GetFieldSQLText(Field: TField): string;
var
  S: string;
  DateTime: TDateTime;
  Bytes: TBizBytes;
  MyBuffer: pointer;
  BlobStream: TMemoryStream;
begin
  if (Field.IsNull) and (Field.DataType in [ftDate, ftDateTime, ftMemo, ftGraphic, ftBytes, ftVarBytes, ftBlob]) then begin
    Result := 'null';
    exit;
  end;

  with Field do
  case DataType of
    ftInteger,ftSmallint,ftFloat,ftCurrency,ftBCD:
      if Field.IsNull then Result := '0'
      else Result := Field.AsString;
    ftBoolean: Result := IntToStr(Integer(Field.AsInteger));
    ftString,ftWideString,ftMemo:
      begin
        //S := Field.AsString;
        //S := PChar(s);
        S := StringReplace(Field.AsString, '''', '''''', [rfReplaceAll]);
        Result := ''''+S+'''';
      end;
    ftDate:
      begin
        DateTime := Field.AsDateTime;
        if (DateTime=0) or (DateTime= 1) then Result := 'null'
        else Result := getsqldatetimetext(DateTime);
      end;
    ftBytes:
      begin
        if DataSize=0 then Result := 'null'
        else begin
          GetMem(MyBuffer, DataSize);
          try
            Bytes.Data := MyBuffer;
            Bytes.Len := DataSize;
            Result := 'E''\\'+charToString(Bytes.Data,bytes.len)+'''';
          finally
            FreeMem(MyBuffer, DataSize);
          end;
        end;
      end;
    ftVarBytes:
      begin
      end;
    ftTime,ftDateTime:
      begin
        DateTime := Field.AsDateTime;
        if (DateTime=0) or (DateTime= 1) then Result := 'null'
        else Result := getsqldatetimetext(DateTime);
      end;
    ftBlob, ftGraphic:
      begin
        try
          BlobStream := TMemoryStream.Create;
          BlobStream.SetSize(0);
          TBlobField(Field).SaveToStream(BlobStream);
          Bytes.Data := BlobStream.Memory;
          Bytes.Len := BlobStream.Size;
          Result := 'E''\\'+charToString(Bytes.Data,bytes.len)+'''';
        finally
          BlobStream.Free;
        end;
      end;
    else
      raise TBizMessage.Create(1,'类型错误');
  end;
end;

function GetSQLDateTimeText(Time: TDateTime): string;
begin
  if Time <= 1 then Result := 'null'
  else Result := ''''+FormatDateTime('yyyymmdd hh:nn:ss', Time)+'''';
  result := stringreplace(result,' 00:00:00','',[]);
end;


procedure stringtochar(const str: string; p: pchar; len: integer);
var
  i,j: integer;
  s: string;
begin
  i := 1;
  j := 0;
  while true do begin
    if j>len-1 then break;
    if i+1>length(str) then break;
    s := copy(str,i,2);
    (p+j)^ := char(strtoint('$'+s));
    inc(j);
    i := i+2;
  end;
end;

function chartostring(p: pchar; len: integer): string;
var
  i,j: integer;
  c: char;
begin
  result := '';
  for i := 0 to len-1 do begin
    c := (p+i)^;
    result := result+format('%2.2x', [integer(c)]);
  end;
end;

function encrypt(key1, key2: integer; Buff: pchar; Len: integer): integer; cdecl; external 'bizutils' name 'bizencrypt';
function decrypt(key1, key2: integer; Buff: pchar; Len: integer): integer; cdecl; external 'bizutils' name 'bizdecrypt';
function ufileexists(pfile: pchar): integer; cdecl; external 'bizutils' name 'bizfileexists';
function bizfileexists(const filename: string): boolean;
begin
  if ufileexists(pchar(filename))<>0 then result := true
  else result := false;
end;

function bizencrypt(key1, key2: integer; Buff: Pchar; Len: integer): integer;
begin
  result := encrypt(key1,key2,buff,len);
end;

function bizdecrypt(key1, key2: integer; Buff: pchar; Len: integer): integer;
begin
  result := decrypt(key1,key2,Buff,len);
end;

function GetFieldDefSQL(datatype: tfieldtype; fieldname: string; Fieldsize,fieldprecision: integer;div4: boolean=true): string;
begin
  result := fieldname;//+'('+inttostr(fieldsize)+')';
  case DataType of    //
    ftBCD:
      begin
        if fieldsize=0 then
          Result := result+' int'
        else begin
          if fieldprecision<=0 then
            Result := result+' numeric(18,'+IntToStr(fieldSize)+')'
          else
            Result := result+' numeric('+IntToStr(fieldPrecision)+','+IntToStr(fieldSize)+')';
        end;
      end;
    ftString, ftWideString:
      if div4 then
        Result := result+' varchar('+IntToStr(fieldSize div 4)+')'
      else
        Result := result+' varchar('+IntToStr(fieldSize)+')';

    ftDate, ftDateTime:
        Result := result+' timestamp';
    ftGraphic, ftBlob, ftOraBlob:
        Result := result+' blob sub_type binary';
    ftMemo, ftOraClob:
        Result := result+' blob sub_type text';
    ftVarBytes, ftBytes:
      Result := result+' varchar('+IntToStr(fieldSize)+')';

    ftInteger, ftSmallInt, ftWord, ftAutoInc:
        Result := result+' int';
    ftFloat:
        Result := result+' float';
    ftFixedChar:
      Result := result+' char('+IntToStr(fieldsize)+')';
  end
end;

procedure bizbuffer(buff: pchar; s: string);
begin
  memcopy(buff, pchar(s), length(s)+1);
end;

function bizstring(p: pchar; len: integer=0): string; overload;
var
  i,j: integer;
begin
  if len>0 then begin
    i := len;
    for j := 0 to i-1 do begin
      if (p+j)^ = chr(0) then begin
        i := j;
        break;
      end;
    end;
  end
  else i := strlen(p);

  setlength(result,i);
  memcopy(pchar(result), p, i);
end;

procedure bizstring(var str: string; p: pchar; len: integer);
var
  i,j: integer;
begin
  if len>0 then begin
    i := len;
    for j := 0 to i-1 do begin
      if (p+j)^ = chr(0) then begin
        i := j;
        break;
      end;
    end;
  end
  else i := strlen(p);

  setlength(str,i);
  memcopy(pchar(str), p, i);
end;

function bizgetwxaccesstoken(servername: string; appid: integer): string;
begin

end;

function bizgetwxjsticket(servername: string; appid: integer): string;
begin

end;

procedure bizfill(p: pointer; len: integer; fill: char);
var
   p1: pchar;
   i: integer;
begin
   p1 := pchar(p);
   for i := 0 to len-1 do begin
     (p1+i)^ := fill;
   end;
end;

function bizunquote(const str: string): string;
var
  i,i1,i2: integer;
begin
  i := length(str);
  i2 := i;
  result := '';
  if i<=0 then exit;
  if str[1]='"' then begin
    i1 := 2;
    i2 := i2-1;
  end
  else i1 :=1;

  if str[i]='"' then begin
    i2 := i2-1;
  end;

  result := copy(str,i1,i2);
end;

procedure loginfo(p:PBizLoginState; p1: pchar; param: array of const); cdecl; external 'bizutils' name 'bizloginfo';
procedure logerror(p:PBizLoginState; p1: pchar; param: array of const); cdecl; external 'bizutils' name 'bizlogerror';
procedure logwarn(p:PBizLoginState; p1: pchar; param: array of const); cdecl; external 'bizutils' name 'bizlogwarn';

procedure memcopy(dest, src : pointer; size : integer);
begin
  Move(src^, dest^, size);
end;

procedure bizloginfo(p: tbizsession; msg: string);
begin
  if p=nil then
    loginfo(nil,pchar(msg), [])
  else
    loginfo(p.loginstate,pchar(msg), []);
end;

procedure bizlogerror(p: tbizsession; msg: string);
begin
  if p=nil then
    logerror(nil,pchar(msg), [])
  else
    logerror(p.loginstate,pchar(msg), []);
end;

procedure bizlogwarn(p: tbizsession; msg: string);
begin
  if p=nil then
    logwarn(nil,pchar(msg), [])
  else
    logwarn(p.loginstate,pchar(msg), []);
end;

function bizsendwxmsg(const accesstoken,wxid,msg: string): string;
var
  s,s1,s2: string;
  str: tstringlist;
  idhttp1: tidhttp;
  IdSSLIOHandlerSocketOpenSSL1: TIdSSLIOHandlerSocketOpenSSL;
  memstream,memstream1: tstringstream;
begin
  try
    str := tstringlist.Create;
    idhttp1 := tidhttp.create(nil);
    IdSSLIOHandlerSocketOpenSSL1 := TIdSSLIOHandlerSocketOpenSSL.create(nil);
    idhttp1.iohandler := IdSSLIOHandlerSocketOpenSSL1;
    memstream := tstringstream.Create('');
    s2 := '{"touser":"'+wxid+'","msgtype":"text","text":{"content":"'+msg+'"}}';
    memstream1 := tstringstream.Create(s2);
    idhttp1.Request.ContentType := 'application/x-www-form-urlencoded';
    idhttp1.Request.Charset := 'utf-8';
    idhttp1.Post('https://api.weixin.qq.com/cgi-bin/message/custom/send?access_token='+accesstoken,memstream1,memstream);
    str.Clear;
    memstream.Position := 0;
    str.LoadFromStream(memstream);
    writeln(wxid+':'+str.text);
  finally
    str.Free;
    memstream1.free;
    memstream.free;
    idhttp1.free;
    IdSSLIOHandlerSocketOpenSSL1.free;
  end;
end;

function BizGetHttpContentType(FileExt: string): string;
begin
  FileExt := UpperCase(FileExt);
  if (FileExt='.HTM') or (FileExt='.HTML') then
    Result := 'text/html'
  else if FileExt = '.TXT' then
    Result := 'text/plain'
  else if FileExt = '.GIF' then
    Result := 'image/gif'
  else if FileExt='.JPG' then
    Result := 'image/jpeg'
  else if FileExt='.PNG' then
    Result := 'image/png'
  else if FileExt='.BMP' then
    Result := 'image/bmp'
  else if FileExt='.DOC' then
    Result := 'application/msword'
  else if FileExt='.DOCX' then
    Result := 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
  else if FileExt='.XLS' then
    Result := 'application/vnd.ms-excel'
  else if FileExt='.XLSX' then
    Result := 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
  else if fileext='.PPT' then
    result := 'application/vnd.ms-powerpoint'
  else if fileext='.PPTX' then
    result := 'application/vnd.openxmlformats-officedocument.presentationml.presentation'
  else if FileExt='.PDF' then
    Result := 'application/pdf'
  else
    Result := 'application/octet-stream';
end;

end.

