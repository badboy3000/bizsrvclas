unit bizstream;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  { tbizstream }

  tbizstream = class
  private
    flist: tlist;
    freadpos: integer;
    fwritepos: integer;
    ftotal: integer;
  public
    constructor create;
    destructor destroy; override;
    procedure loadfromstream(stream: tmemorystream);
    procedure loadfromfile(filename: pchar);
    procedure loadfromfile(filename: string);
    procedure savetofile(filename: pchar);
    procedure savetofile(filename: string);
    procedure writeint(i: integer);
    procedure writeint64(i: int64);
    procedure writestring(const val: string);
    procedure writechar(b: char);
    procedure writebuffer(p: pchar; len: integer);
    function writebuffer(stream: tstream; len: integer): integer;
    procedure writedatetime(dt: tdatetime);
    procedure writeextended(d: extended);
    function readint: integer;
    function readint64: integer;
    function readstring: string;
    function readchar: char;
    function readbuffer(p: pchar; len: integer): integer;
    function readdatetime: tdatetime;
    procedure reset;
    property total: integer read ftotal;
    procedure writelen;
  end;

  { tbizmemorystream }

  tbizmemorystream = class(tmemorystream)
  private
  public
    procedure writeint(i: integer);
    procedure writeint64(i: int64);
    procedure writestring(const val: string);
    procedure writechar(b: char);
    procedure writebuff(p: pchar; len: integer);
    procedure writedatetime(dt: tdatetime);
    procedure writeextended(d: extended);
  end;

implementation
uses bizsrvclass,bizutils;

{ tbizmemorystream }

procedure tbizmemorystream.writeint(i: integer);
begin
  writebuff(pchar(@i),4);
end;

procedure tbizmemorystream.writeint64(i: int64);
begin
  writebuff(pchar(@i),8);
end;

procedure tbizmemorystream.writestring(const val: string);
var
  totlen: integer;
begin
  totlen := length(val);
  writeint(totlen);
  if totlen>0 then
    writebuff(pchar(val), totlen);
end;

procedure tbizmemorystream.writechar(b: char);
begin
  writebuff(pchar(@b),1);
end;

procedure tbizmemorystream.writebuff(p: pchar; len: integer);
begin
  writebuffer(p^, len);
end;

procedure tbizmemorystream.writedatetime(dt: tdatetime);
begin
  writebuff(pchar(@dt),sizeof(tdatetime));
end;

procedure tbizmemorystream.writeextended(d: extended);
begin
  writebuff(pchar(@d),sizeof(extended));
end;

{ tbizstream }

constructor tbizstream.create;
var
  p: pointer;
begin
  flist := tlist.create;
  p := getmem(BLOCKSIZE);
  flist.add(p);
  freadpos := 0;
  fwritepos := 0;
  ftotal := 0;
end;

destructor tbizstream.destroy;
var
  i: integer;
begin
  for i := 0 to flist.count-1 do begin
    freemem(flist[i]);
  end;

  flist.clear;
  flist.free;
  inherited destroy;
end;

procedure tbizstream.loadfromstream(stream: tmemorystream);
var
  i: integer;
  filestream: tfilestream;
  buff: array[1..2048] of char;
begin
  freadpos := 0;
  fwritepos := 0;
  ftotal := 0;
  stream.Position := 0;
  while true do begin
    i := stream.Read(buff, 2048);
    if i<=0 then break
    else begin
      writebuffer(pchar(@buff[1]), i);
    end;
  end;
end;

procedure tbizstream.loadfromfile(filename: pchar);
var
  s: string;
begin
  s := bizstring(filename);
  loadfromfile(s);
end;

procedure tbizstream.loadfromfile(filename: string);
var
  i: integer;
  filestream: tfilestream;
  buff: array[1..2048] of char;
begin
  freadpos := 0;
  fwritepos := 0;
  ftotal := 0;
  if not fileexists(filename) then exit;
  try
    filestream := tfilestream.Create(filename,fmopenread);
    while true do begin
      i := filestream.Read(buff, 2048);
      if i<=0 then break
      else begin
        writebuffer(pchar(@buff[1]), i);
      end;
    end;
  finally
    filestream.free;
  end;
end;

procedure tbizstream.savetofile(filename: pchar);
var
  s: string;
begin
  s := bizstring(filename);
  savetofile(s);
end;

procedure tbizstream.savetofile(filename: string);
var
  block,last,i: integer;
  filestream: tfilestream;
begin
  if ftotal<=0 then begin
    block := 0;
    last := 0;
  end
  else begin
    block := ((ftotal-1) div BLOCKSIZE)+1;
    last := ftotal-(block-1)*BLOCKSIZE;
  end;

  deletefile(filename);
  try
    filestream := tfilestream.Create(filename,fmcreate or fmopenreadwrite);
    for i := 0 to block-1 do begin
      if i=block-1 then
        filestream.writebuffer(pchar(flist[i])^, last)
      else
        filestream.writebuffer(pchar(flist[i])^, BLOCKSIZE);
    end;
  finally
    filestream.free;
  end;
end;

procedure tbizstream.writeint(i: integer);
begin
  writebuffer(pchar(@i), sizeof(integer));
end;

procedure tbizstream.writeint64(i: int64);
begin
  writebuffer(pchar(@i), sizeof(int64));
end;

procedure tbizstream.writestring(const val: string);
var
  totlen: integer;
begin
  totlen := length(val);
  writeint(totlen);
  if totlen>0 then
    writebuffer(pchar(val), totlen);
end;

procedure tbizstream.writechar(b: char);
begin
  writebuffer(pchar(@b), sizeof(char));
end;

procedure tbizstream.writebuffer(p: pchar; len: integer);
var
  writed,totlen,block,posi: integer;
  p1: pchar;
begin
  if len=0 then exit;
  block := (fwritepos and  $ffff0000) shr 16;
  posi := fwritepos and $ffff;
  totlen := len;
  writed := 0;
  while true do begin
    if block+1>flist.count then begin
      p1 := getmem(BLOCKSIZE);
      flist.add(p1);
    end;

    if totlen-writed<=BLOCKSIZE-posi then begin
      memcopy(pchar(flist[block])+posi,p+writed,totlen-writed);
      ftotal := ftotal+totlen-writed;
      fwritepos := (block shl 16)+posi+totlen-writed;
      break;
    end
    else begin
      memcopy(pchar(flist[block])+posi,p+writed,BLOCKSIZE-posi);
      ftotal := ftotal+BLOCKSIZE-posi;
      writed := BLOCKSIZE-posi;
      inc(block);
      posi := 0;
    end;
  end;
end;

function tbizstream.writebuffer(stream: tstream; len: integer): integer;
var
  B: array[1..2048] of char;
  i,j,r: integer;
begin
  result := 0;
  repeat
    if len>=2048 then
      j := 2048
    else
      j := len;

    R := stream.Read(B, j);
    if R > 0 then begin
      if r<=len then begin
        len := len-r;
        writebuffer(pchar(@b[1]), r);
        result := result+r;
      end
      else begin
        writebuffer(pchar(@b[1]), len);
        result := result+len;
        break;
      end;
    end;
  until R < 2048;
end;

procedure tbizstream.writedatetime(dt: tdatetime);
begin
  writebuffer(pchar(@dt), sizeof(tdatetime));
end;

procedure tbizstream.writeextended(d: extended);
begin
  writebuffer(pchar(@d), sizeof(extended));
end;

function tbizstream.readint: integer;
var
  n: integer;
begin
  readbuffer(pchar(@n), sizeof(integer));
  result := n;
end;

function tbizstream.readint64: integer;
var
  n: int64;
begin
  readbuffer(pchar(@n), sizeof(int64));
  result := n;
end;

function tbizstream.readstring: string;
var
  i: integer;
  s: string;
begin
  result := '';
  i := readint;
  if i<=0 then exit;
  setlength(result, i);
  readbuffer(pchar(result), i);
end;

function tbizstream.readchar: char;
var
  c: char;
begin
  readbuffer(@c, sizeof(char));
  result := c;
end;

function tbizstream.readbuffer(p: pchar; len: integer): integer;
var
  block,posi,readed,tmp: integer;
begin
  block := (freadpos and $ffff0000) shr 16;
  posi := freadpos and $ffff;
  tmp := ftotal-block*BLOCKSIZE-posi;
  if len>tmp then
    len := tmp;

  if len<=0 then begin
    result := 0;
    exit;
  end;

  readed := 0;
  while true do begin
    if block*BLOCKSIZE+posi+1>ftotal then
      break;

    if len-readed<=BLOCKSIZE-posi then begin
      memcopy(p+readed,pchar(flist[block])+posi,len-readed);
      freadpos := (block shl 16)+posi+len-readed;
      readed := len;
      break;
    end
    else begin
      memcopy(p+readed,pchar(flist[block])+posi,BLOCKSIZE-posi);
      readed := readed+BLOCKSIZE-posi;
      inc(block);
      posi := 0;
    end
  end;

  result := readed;
end;

function tbizstream.readdatetime: tdatetime;
var
  d: tdatetime;
begin
  readbuffer(pchar(@d), sizeof(tdatetime));
  result := d;
end;

procedure tbizstream.reset;
begin
  freadpos := 0;
  fwritepos := 0;
  ftotal := 0;
end;

procedure tbizstream.writelen;
var
  p: pinteger;
begin
  p := flist[0];
  p^ := ftotal;
end;

end.

