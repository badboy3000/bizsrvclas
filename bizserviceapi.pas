unit bizserviceapi;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, bizsrvclass,bizutils;

procedure bizinitwebservice(p: PBizServerParam; package: PTmpPackageEntry; packagecount: integer); cdecl;
function bizrequestservice(loginstate: PBizloginState; cancache,pkgid, svcid: integer; const path, query, param: pchar; var returl: pchar; var errcode: integer; var error: pchar): pchar; cdecl;
procedure bizbinaryrequestservice(loginstate: PBizloginState; cancache,pkgid, svcid: integer; const path, query, filename: pchar; var returl: pchar; var errcode: integer; var error: pchar); cdecl;
procedure bizinitsession(loginstate: PBizloginState); cdecl;
procedure bizexitsession; cdecl;
procedure bizexitwebservice; cdecl;
procedure bizregisterpackage(package: PTmpPackageEntry);
function bizgetfilename: pchar;
procedure bizinitconsolesession(appid: integer; locserverparam: PBizserverparam; var session: TBizSession); cdecl;
implementation
var
  tmploginstate: TBizLoginState;

function getpid:longint;cdecl;external 'libc' name 'getpid';
function bizgetfilename: pchar;
begin
  tmpfilename := bizstring(@serverparam^.tmppath[1])+'task/'+biztempname;
  result := pchar(tmpfilename);
end;

procedure incservicecount(appid: integer);
var
  s,s1: string;
begin
  exit;
  s := bizstring(@serverparam^.tmppath[1])+'STASTIC'+formatdatetime('yyyymmdd',date)+'-'+inttostr(getpid())+'-'+inttostr(appid);
  s1 := bizreadfilestring(s);
  if s1='' then
    bizwritefilestring(s,'1')
  else begin
    try
      bizwritefilestring(s,inttostr(strtoint(s1)+1));
    except
      bizwritefilestring(s,'1');
    end;
  end;
end;

procedure bizregisterpackage(package: PTmpPackageEntry);
var
  i: integer;
  packageid: integer;
  service: PServiceEntry;
  svccount: integer;
  desc: string;
begin
  packageid := package^.pkgid;
  service := package^.service;
  svccount := package^.svccount;
  desc := package^.desc;

  for i := 0 to svccount-1 do begin
    packagelist[packageid].service[i+1].svcid := service^.svcid;
    packagelist[packageid].service[i+1].serviceproc := service^.serviceproc;
    packagelist[packageid].service[i+1].isbinary := service^.isbinary;
    packagelist[packageid].service[i+1].desc := service^.desc;
    service := PServiceEntry(pbyte(service)+sizeof(TServiceEntry));
  end;

  packagelist[packageid].svccount := svccount;
  packagelist[packageid].desc := desc;
  packagelist[packageid].isok := 1;
end;

procedure bizinitwebservice(p: PBizServerParam; package: PTmpPackageEntry; packagecount: integer); cdecl;
var
  i: integer;
  s: string;
  txtfile: tbiztextfile;
  str: tstringlist;
  currentry: integer;
  p1: pchar;
begin
  if zhmsgmap=nil then begin
    zhmsgmap := TISMap.create;
    Trmsgmap := TISMap.create;
    Enmsgmap := TISMap.create;
    Frmsgmap := TISMap.create;
    Dumsgmap := TISMap.create;
    Jpmsgmap := TISMap.create;
    Krmsgmap := TISMap.create;
    Spmsgmap := TISMap.create;
    Rumsgmap := TISMap.create;
    initmsg;
  end;

  serverparam := p;
  bizstring(s, @serverparam^.servername[1]);
  if s='' then
    bizbuffer(@serverparam^.servername[1],'NONE');

  bizstring(s, @serverparam^.tmppath[1]);
  if s='' then
    bizbuffer(@serverparam^.tmppath[1],'/home/fausten/ramdisk/');

  // get wxappid & wxsecret
  try
    txtfile := tbiztextfile.create;
    str := tstringlist.create;
    txtfile.openexistfile('/etc/ebizmis.conf',true,ftutf8);
    currentry := 0;
    while not txtfile.eof do begin
      s := txtfile.readln;
      if (copy(s,1,2)='//') or (trim(s)='') then continue
      else begin
        if copy(s,1,9)='[ebizmis.' then begin
          s := copy(s,10,10);
          s := stringreplace(s,']','',[rfreplaceall]);
          currentry := strtoint(s);
        end
        else begin
          delimitstring(s,'=',str);
          s := str[1];
          p1 := pchar(s);
          if str[0]='wxappid' then
            strcopy(@serverparam^.wxappid[currentry][1],p1)
          else if str[0]='servername' then begin
            s := uppercase(str[1]);
            p1 := pchar(s);
            strcopy(@serverparam^.appservername[currentry][1],p1);
          end
          else if str[0]='wxsecret' then
            strcopy(@serverparam^.wxsecret[currentry][1],p1);
        end;
      end;
    end;
  finally
    txtfile.free;
    str.free;
  end;

  for i := 1 to packagecount do begin
    bizregisterpackage(package);
    package := PTmpPackageEntry(pbyte(package)+sizeof(TTmpPackageEntry));
  end;
end;

procedure bizinitsession(loginstate: PBizloginState); cdecl;
var
  s: string;
begin
  try
    if mysession=nil then begin
      mysession := TBizSession.Create;
      bizstring(s, @serverparam^.servername[1]);
      mysession.globalservername := s;
      bizstring(s, @serverparam^.tmppath[1]);
      mysession.tmppath := s;
    end;

    bizstring(s,@serverparam^.appservername[loginstate^.appid][1]);
    mysession.servername := s;
    mysession.initsession(loginstate);
  except
    on e: exception do begin
      bizloginfo(nil, e.message);
    end;
  end;
end;

procedure bizexitsession; cdecl;
begin
  try
    if mysession=nil then
      mysession := TBizSession.Create;

    mysession.exitsession;
  except
    on e: exception do
       bizloginfo(nil, 'exit session error: '+e.message);
  end;
end;

function bizrequestservice(loginstate: PBizloginState; cancache, pkgid, svcid: integer; const path, query, param: pchar; var returl: pchar; var errcode: integer; var error: pchar): pchar; cdecl;
var
  strparam,strpath,strquery: string;
  i: integer;
  svcproc: TServiceProc;
  p: pchar;
  s,s1,s2,s3: string;
  v: variant;
begin
  s1 := bizstring(path);
  s2 := bizstring(query);
  s3 := bizstring(param);
  //bizloginfo(mysession,'session.appid:'+inttostr(mysession.loginstate^.appid)+',pkg:'+inttostr(pkgid)+',svcid:'+inttostr(svcid)+',path:'+s1+',query:'+query+',param:'+param);
  //bizloginfo(mysession,'enter lazarus');
  retresult := '';
  redirecturl := '';
  errcode := 0;
  reterror := '';
  error := pchar(reterror);
  returl := pchar(redirecturl);
  result := pchar(retresult);
  mysession.appid := loginstate^.appid;
  incservicecount(mysession.appid);

  if (pkgid<=0) or (pkgid>100) then begin
    errcode := 1;
    reterror := 'package:'+inttostr(pkgid)+' not found!';
    error := pchar(reterror);
    result := pchar(reterror);
    exit;
  end;

  if packagelist[pkgid].isok<>1 then begin
    errcode := 1;
    reterror := 'package:'+inttostr(pkgid)+' not found!';
    error := pchar(reterror);
    result := pchar(reterror);
    exit;
  end;

  if svcid>packagelist[pkgid].svccount then begin
    errcode := 1;
    reterror := 'service:'+inttostr(pkgid)+'-'+inttostr(svcid)+' not found!';
    error := pchar(reterror);
    result := pchar(reterror);
    exit;
  end;

  i := 0;
  //bizloginfo(mysession,'before call serviceA');
  if param=nil then
    strparam := ''
  else
    strparam := param;

  //bizloginfo(mysession,'before call serviceB');
  if path=nil then
    strpath := ''
  else
    strpath := path;

  if query=nil then
    strquery := ''
  else
    strquery := query;

  errcode := 0;
  reterror := '';
  svcproc := packagelist[pkgid].service[svcid].serviceproc;
  try
    if @svcproc<> nil then begin
      bizloginfo(mysession,'before call service: '+format('%x',[integer(@svcproc)])+', pkg:'+inttostr(pkgid)+',svc:'+inttostr(svcid));
      retresult := svcproc(mysession,mysession.loginstate^.appid,strpath,strquery,strparam,redirecturl,i);
    end
    else
      retresult := '';

    returl := pchar(redirecturl);
    if path<>'' then begin
      v := now;
      s := bizmd5string(path);
      mysession.insert('biz_pageclick','c_md5,c_path,c_query,i_user_id,d_time,i_pkg,i_srv',
        [s,strpath,strquery,mysession.uid,formatdatetime('yyyymmdd hh:nn:ss.zzz',v),pkgid,svcid]);
    end;
  except
    on e: exception do begin
      errcode := 1;
      reterror := e.message;
      retresult := e.message;
      error := pchar(reterror);
      bizloginfo(mysession, 'error:'+e.message);
    end;
  end;

  //bizloginfo(mysession,'after call service');
  result := pchar(retresult);
end;

procedure bizbinaryrequestservice(loginstate: PBizloginState; cancache,pkgid, svcid: integer; const path, query, filename: pchar; var returl: pchar; var errcode: integer; var error: pchar); cdecl;
var
  strparam,strpath,strquery: string;
  i: integer;
  svcproc: TServiceProc;
  p: pchar;
  s1,s2,s3: string;
  datalen: integer;
  procedure responseerror(ecode: integer; const etext: string);
  begin
    mysession.writestream.reset;
    mysession.writestream.writeint(0);
    mysession.writestream.writeint(ecode);
    mysession.writestream.writestring(etext);
    mysession.writestream.writelen;
    mysession.writestream.savetofile(filename);
  end;
begin
  s1 := bizstring(path);
  s2 := bizstring(query);
  s3 := bizstring(filename);
  bizloginfo(mysession,'binaryrequest session.appid:'+inttostr(mysession.loginstate^.appid)+',login:'+inttostr(integer(mysession.islogin))+','+inttostr(loginstate^.islogin)+',pkg:'+inttostr(pkgid)+',svcid:'+inttostr(svcid)+',path:'+s1+',query:'+query+',filename:'+filename);
  retresult := '';
  redirecturl := '';
  errcode := 0;
  reterror := '';
  error := pchar(reterror);
  returl := pchar(redirecturl);
  mysession.appid := loginstate^.appid;
  incservicecount(mysession.appid);
  mysession.writestream.reset;
  mysession.readstream.reset;
  mysession.readstream.loadfromfile(filename);
  datalen := mysession.readstream.readint;
  pkgid := mysession.readstream.readint;
  svcid := mysession.readstream.readint;
  loginstate^.pkgid := pkgid;
  loginstate^.svcid := svcid;
  if datalen<>mysession.readstream.total then begin
    responseerror(1,'received data corrupted!');
    exit;
  end;

  //pkgid := 1;
  //svcid := 4;
  bizloginfo(mysession,'load file:'+filename+','+inttostr(mysession.readstream.total)+',pkg:'+inttostr(pkgid)+',svcid:'+inttostr(svcid));
  if (pkgid<=0) or (pkgid>100) then begin
    responseerror(1,'package:'+inttostr(pkgid)+' not found!');
    exit;
  end;

  if packagelist[pkgid].isok<>1 then begin
    responseerror(1,'package:'+inttostr(pkgid)+' not found!');
    exit;
  end;

  if svcid>packagelist[pkgid].svccount then begin
    responseerror(1,'service:'+inttostr(pkgid)+'-'+inttostr(svcid)+' not found!');
    exit;
  end;

  i := 0;
  if filename=nil then
    strparam := ''
  else
    strparam := filename;

  if path=nil then
    strpath := ''
  else
    strpath := path;

  if query=nil then
    strquery := ''
  else
    strquery := query;

  errcode := 0;
  reterror := '';
  if (not packagelist[pkgid].service[svcid].isbinary) then begin
    responseerror(1,'只能调用binary服务!');
    exit;
  end;

  if (not mysession.islogin) and ((pkgid<>1) or (svcid<>5)) then begin
    responseerror(9,'请先登录!');
    exit;
  end;

  svcproc := packagelist[pkgid].service[svcid].serviceproc;
  mysession.writeint(0); // len
  mysession.writeint(0); // retcode
  try
    if @(packagelist[pkgid].service[svcid].serviceproc)<> nil then
      packagelist[pkgid].service[svcid].serviceproc(mysession,mysession.loginstate^.appid,strpath,strquery,strparam,redirecturl,i);
    mysession.writestream.writelen;
  except
    on e: exception do begin
      errcode := 1;
      reterror := e.message;
      responseerror(1,e.message);
      bizloginfo(mysession, e.message);
    end;
  end;

  mysession.writestream.savetofile(filename);
end;

procedure bizexitwebservice; cdecl;
begin

end;

procedure bizsetserverparam(p:pointer); cdecl; external 'bizutils';
procedure bizinitconsolesession(appid: integer; locserverparam: PBizserverparam; var session: TBizSession); cdecl;
var
  s,s1,s2,appservername: string;
  txtfile: tbiztextfile;
  str: tstringlist;
  currappid: integer;
begin
  serverparam := locserverparam;
  try
    txtfile := tbiztextfile.create;
    str := tstringlist.create;
    if fileexists('/usr/php7/php.ini') then
      txtfile.openexistfile('/usr/php7/php.ini',true,ftutf8)
    else
      txtfile.openexistfile('/etc/php.ini',true,ftutf8);

    while not txtfile.eof do begin
      s := txtfile.readln;
      if (copy(s,1,2)='//') or (trim(s)='') then continue;
      delimitstring(s,'=',str);
      if (str.count=2) and (copy(str[0],1,8)='ebizmis.') then begin
        s1 := str[0];
        s2 := str[1];
        if s1='ebizmis.tmppath' then memcopy(@(serverparam^.tmppath[1]),pchar(s2),length(s2)+1)
        else if s1='ebizmis.stddb' then memcopy(@(serverparam^.stddb[1]),pchar(s2),length(s2)+1)
        else if s1='ebizmis.servername' then memcopy(@(serverparam^.servername[1]),pchar(s2),length(s2)+1)
        else if s1='ebizmis.dbserver' then memcopy(@(serverparam^.dbserver[1]),pchar(s2),length(s2)+1)
        else if s1='ebizmis.dbport' then serverparam^.dbport := strtoint(s2)
        else if s1='ebizmis.dbname' then memcopy(@(serverparam^.dbname[1]),pchar(s2),length(s2)+1)
        else if s1='ebizmis.dbusername' then memcopy(@(serverparam^.dbusername[1]),pchar(s2),length(s2)+1)
        else if s1='ebizmis.dbpassword' then memcopy(@(serverparam^.dbpassword[1]),pchar(s2),length(s2)+1)
        else if s1='ebizmis.appdb_'+inttostr(appid) then memcopy(@(serverparam^.appdb[appid][1]),pchar(s2),length(s2)+1)
      end;
    end;
  finally
    txtfile.free;
    str.free;
  end;

  appservername:='';
  try
    txtfile := tbiztextfile.create;
    str := tstringlist.create;
    txtfile.openexistfile('/etc/ebizmis.conf',true,ftutf8);
    currappid := 0;
    while not txtfile.eof do begin
      s := txtfile.readln;
      if (copy(s,1,2)='//') or (trim(s)='') then continue;
      if s='[ebizmis.'+inttostr(appid)+']' then begin
        currappid := appid;
      end;

      if currappid<>appid then continue;
      delimitstring(s,'=',str);
      if (str.count=2) and (str[0]='servername') then begin
        appservername := str[1];
        break;
      end;
    end;
  finally
    txtfile.free;
    str.free;
  end;

  bizsetserverparam(locserverparam);
  session := nil;
  session := tbizsession.create;
  mysession := session;
  bizstring(s, @serverparam^.servername[1]);
  mysession.globalservername := s;
  bizstring(s, @serverparam^.tmppath[1]);
  mysession.tmppath := s;
  //bizstring(s,@serverparam^.appservername[appid][1]);
  if appservername<>'' then
    mysession.servername := appservername
  else
    mysession.servername := 'NULL';

  tmploginstate.appid := appid;
  mysession.initsession(@tmploginstate);
end;

end.

