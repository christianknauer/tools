#!/usr/bin/env bash

# source: https://github.com/grondilu/bitcoin-bash-tools

# requires: 
# - dc (apt instal dc)

# This file requires extended globs to be parsed
shopt -s extglob

bip39_words()
  case "${LANG::5}" in
    # lists of words from https://github.com/bitcoin/bips/tree/master/bip-0039
    *)       echo a{b{andon,ility,le,o{ut,ve},s{ent,orb,tract,urd},use},c{c{ess,ident,ount,use},hieve,id,oustic,quire,ross,t{,ion,or,ress,ual}},d{apt,d{,ict,ress},just,mit,ult,v{ance,ice}},erobic,f{f{air,ord},raid},g{ain,e{,nt},ree},head,i{m,r{,port},sle},l{arm,bum,cohol,ert,ien,l{,ey,ow},most,one,pha,ready,so,ter,ways},m{a{teur,zing},o{ng,unt},used},n{alyst,c{hor,ient},g{er,le,ry},imal,kle,n{ounce,ual},other,swer,t{enna,ique},xiety,y},p{art,ology,p{ear,le,rove},ril},r{c{h,tic},e{a,na},gue,m{,ed,or,y},ound,r{ange,est,ive,ow},t{,efact,ist,work}},s{k,pect,s{ault,et,ist,ume},thma},t{hlete,om,t{ack,end,itude,ract}},u{ction,dit,gust,nt,t{hor,o,umn}},v{erage,o{cado,id}},w{a{ke,re,y},esome,ful,kward},xis} b{a{by,c{helor,on},dge,g,l{ance,cony,l},mboo,n{ana,ner},r{,ely,gain,rel},s{e,ic,ket},ttle},e{a{ch,n,uty},c{ause,ome},ef,fore,gin,h{ave,ind},l{ieve,ow,t},n{ch,efit},st,t{ray,ter,ween},yond},i{cycle,d,ke,nd,ology,r{d,th},tter},l{a{ck,de,me,nket,st},e{ak,ss},ind,o{od,ssom,use},u{e,r,sh}},o{a{rd,t},dy,il,mb,n{e,us},o{k,st},r{der,ing,row},ss,ttom,unce,x,y},r{a{cket,in,nd,ss,ve},e{ad,eze},i{ck,dge,ef,ght,ng,sk},o{ccoli,ken,nze,om,ther,wn},ush},u{bble,d{dy,get},ffalo,ild,l{b,k,let},n{dle,ker},r{den,ger,st},s{,iness,y},tter,yer,zz}} c{a{b{bage,in,le},ctus,ge,ke,l{l,m},m{era,p},n{,al,cel,dy,non,oe,vas,yon},p{able,ital,tain},r{,bon,d,go,pet,ry,t},s{e,h,ino,tle,ual},t{,alog,ch,egory,tle},u{ght,se,tion},ve},e{iling,lery,ment,n{sus,tury},r{eal,tain}},h{a{ir,lk,mpion,nge,os,pter,rge,se,t},e{ap,ck,ese,f,rry,st},i{cken,ef,ld,mney},o{ice,ose},ronic,u{ckle,nk,rn}},i{gar,nnamon,rcle,t{izen,y},vil},l{a{im,p,rify,w,y},e{an,rk,ver},i{ck,ent,ff,mb,nic,p},o{ck,g,se,th,ud,wn},u{b,mp,ster,tch}},o{a{ch,st},conut,de,ffee,i{l,n},l{lect,or,umn},m{bine,e,fort,ic,mon,pany},n{cert,duct,firm,gress,nect,sider,trol,vince},o{k,l},p{per,y},r{al,e,n,rect},st,tton,u{ch,ntry,ple,rse,sin},ver,yote},r{a{ck,dle,ft,m,ne,sh,ter,wl,zy},e{am,dit,ek,w},i{cket,me,sp,tic},o{p,ss,uch,wd},u{cial,el,ise,mble,nch,sh},y{,stal}},u{be,lture,p{,board},r{ious,rent,tain,ve},s{hion,tom},te},ycle} d{a{d,m{age,p},n{ce,ger},ring,sh,ughter,wn,y},e{al,b{ate,ris},c{ade,ember,ide,line,orate,rease},er,f{ense,ine,y},gree,l{ay,iver},m{and,ise},n{ial,tist,y},p{art,end,osit,th,uty},rive,s{cribe,ert,ign,k,pair,troy},t{ail,ect},v{elop,ice,ote}},i{a{gram,l,mond,ry},ce,e{sel,t},ffer,g{ital,nity},lemma,n{ner,osaur},r{ect,t},s{agree,cover,ease,h,miss,order,play,tance},v{ert,ide,orce},zzy},o{c{tor,ument},g,l{l,phin},main,n{ate,key,or},or,se,uble,ve},r{a{ft,gon,ma,stic,w},e{am,ss},i{ft,ll,nk,p,ve},op,um,y},u{ck,mb,ne,ring,st,t{ch,y}},warf,ynamic} e{a{g{er,le},r{ly,n,th},s{ily,t,y}},c{ho,o{logy,nomy}},d{ge,it,ucate},ffort,gg,i{ght,ther},l{bow,der,e{ctric,gant,ment,phant,vator},ite,se},m{b{ark,ody,race},erge,otion,p{loy,ower,ty}},n{a{ble,ct},d{,less,orse},e{my,rgy},force,g{age,ine},hance,joy,list,ough,r{ich,oll},sure,t{er,ire,ry},velope},pisode,qu{al,ip},r{a{,se},o{de,sion},ror,upt},s{cape,s{ay,ence},tate},t{ernal,hics},v{i{dence,l},o{ke,lve}},x{a{ct,mple},c{ess,hange,ite,lude,use},e{cute,rcise},h{aust,ibit},i{le,st,t},otic,p{and,ect,ire,lain,ose,ress},t{end,ra}},ye{,brow}} f{a{bric,c{e,ulty},de,i{nt,th},l{l,se},m{e,ily,ous},n{,cy,tasy},rm,shion,t{,al,her,igue},ult,vorite},e{ature,bruary,deral,e{,d,l},male,nce,stival,tch,ver,w},i{ber,ction,eld,gure,l{e,m,ter},n{al,d,e,ger,ish},r{e,m,st},s{cal,h},t{,ness},x},l{a{g,me,sh,t,vor},ee,i{ght,p},o{at,ck,or,wer},u{id,sh},y},o{am,cus,g,il,l{d,low},o{d,t},r{ce,est,get,k,tune,um,ward},s{sil,ter},und,x},r{a{gile,me},e{quent,sh},i{end,nge},o{g,nt,st,wn,zen},uit},u{el,n{,ny},r{nace,y},ture}} g{a{dget,in,l{axy,lery},me,p,r{age,bage,den,lic,ment},s{,p},t{e,her},uge,ze},e{n{eral,ius,re,tle,uine},sture},host,i{ant,ft,ggle,nger,r{affe,l},ve},l{a{d,nce,re,ss},i{de,mpse},o{be,om,ry,ve,w},ue},o{at,ddess,ld,o{d,se},rilla,s{pel,sip},vern,wn},r{a{b,ce,in,nt,pe,ss,vity},e{at,en},i{d,ef,t},o{cery,up,w},unt},u{ard,ess,i{de,lt,tar},n},ym} h{a{bit,ir,lf,m{mer,ster},nd,ppy,r{bor,d,sh,vest},t,ve,wk,zard},e{a{d,lth,rt,vy},dgehog,ight,l{lo,met,p},n,ro},i{dden,gh,ll,nt,p,re,story},o{bby,ckey,l{d,e,iday,low},me,ney,od,pe,r{n,ror,se},s{pital,t},tel,ur,ver},u{b,ge,m{an,ble,or},n{dred,gry,t},r{dle,ry,t},sband},ybrid} i{c{e,on},d{e{a,ntify},le},gnore,ll{,egal,ness},m{age,itate,m{ense,une},p{act,ose,rove,ulse}},n{c{h,lude,ome,rease},d{ex,icate,oor,ustry},f{ant,lict,orm},h{ale,erit},itial,j{ect,ury},mate,n{er,ocent},put,quiry,s{ane,ect,ide,pire,tall},t{act,erest,o},v{est,ite,olve}},ron,s{land,olate,sue},tem,vory} j{a{cket,guar,r,zz},e{a{lous,ns},lly,wel},o{b,in,ke,urney,y},u{dge,ice,mp,n{gle,ior,k},st}} k{angaroo,e{e{n,p},tchup,y},i{ck,d{,ney},n{d,gdom},ss,t{,chen,e,ten},wi},n{ee,ife,o{ck,w}}} l{a{b{,el,or},d{der,y},ke,mp,nguage,ptop,rge,t{er,in},u{gh,ndry},va,w{,n,suit},yer,zy},e{a{der,f,rn,ve},cture,ft,g{,al,end},isure,mon,n{d,gth,s},opard,sson,tter,vel},i{ar,b{erty,rary},cense,f{e,t},ght,ke,m{b,it},nk,on,quid,st,ttle,ve,zard},o{a{d,n},bster,c{al,k},gic,n{ely,g},op,ttery,u{d,nge},ve,yal},u{cky,ggage,mber,n{ar,ch},xury},yrics} m{a{chine,d,g{ic,net},i{d,l,n},jor,ke,mmal,n{,age,date,go,sion,ual},ple,r{ble,ch,gin,ine,ket,riage},s{k,s,ter},t{ch,erial,h,rix,ter},ximum,ze},e{a{dow,n,sure,t},chanic,d{al,ia},l{ody,t},m{ber,ory},n{tion,u},r{cy,ge,it,ry},s{h,sage},t{al,hod}},i{d{dle,night},l{k,lion},mic,n{d,imum,or,ute},r{acle,ror},s{ery,s,take},x{,ed,ture}},o{bile,d{el,ify},m{,ent},n{itor,key,ster,th},on,r{al,e,ning},squito,t{her,ion,or},u{ntain,se},v{e,ie}},u{ch,ffin,l{e,tiply},s{cle,eum,hroom,ic,t},tual},y{s{elf,tery},th}} n{a{ive,me,pkin,rrow,sty,t{ion,ure}},e{ar,ck,ed,g{ative,lect},ither,phew,rve,st,t{,work},utral,ver,ws,xt},i{ce,ght},o{ble,ise,minee,odle,r{mal,th},se,t{able,e,hing,ice},vel,w},u{clear,mber,rse,t}} o{ak,b{ey,ject,lige,s{cure,erve},tain,vious},c{cur,ean,tober},dor,f{f{,er,ice},ten},il,kay,l{d,ive,ympic},mit,n{ce,e,ion,l{ine,y}},p{e{n,ra},inion,pose,tion},r{ange,bit,chard,d{er,inary},gan,i{ent,ginal},phan},strich,ther,ut{door,er,put,side},v{al,e{n,r}},wn{,er},xygen,yster,zone} p{a{ct,ddle,ge,ir,l{ace,m},n{da,el,ic,ther},per,r{ade,ent,k,rot,ty},ss,t{ch,h,ient,rol,tern},use,ve,yment},e{a{ce,nut,r,sant},lican,n{,alty,cil},ople,pper,r{fect,mit,son},t},h{o{ne,to},rase,ysical},i{ano,c{nic,ture},ece,g{,eon},l{l,ot},nk,oneer,pe,stol,tch,zza},l{a{ce,net,stic,te,y},e{ase,dge},u{ck,g,nge}},o{e{m,t},int,l{ar,e,ice},n{d,y},ol,pular,rtion,s{ition,sible,t},t{ato,tery},verty,w{der,er}},r{a{ctice,ise},e{dict,fer,pare,sent,tty,vent},i{ce,de,mary,nt,ority,son,vate,ze},o{blem,cess,duce,fit,gram,ject,mote,of,perty,sper,tect,ud,vide}},u{blic,dding,l{l,p,se},mpkin,nch,p{il,py},r{chase,ity,pose,se},sh,t,zzle},yramid} qu{a{lity,ntum,rter},estion,i{ck,t,z},ote} r{a{bbit,c{coon,e,k},d{ar,io},i{l,n,se},lly,mp,n{ch,dom,ge},pid,re,t{e,her},ven,w,zor},e{a{dy,l,son},b{el,uild},c{all,eive,ipe,ord,ycle},duce,f{lect,orm,use},g{ion,ret,ular},ject,l{ax,ease,ief,y},m{ain,ember,ind,ove},n{der,ew,t},open,p{air,eat,lace,ort},quire,s{cue,emble,ist,ource,ponse,ult},t{ire,reat,urn},union,v{eal,iew},ward},hythm,i{b{,bon},c{e,h},d{e,ge},fle,g{ht,id},ng,ot,pple,sk,tual,v{al,er}},o{a{d,st},b{ot,ust},cket,mance,o{f,kie,m},se,tate,u{gh,nd,te},yal},u{bber,de,g,le,n{,way},ral}} s{a{d{,dle,ness},fe,il,l{ad,mon,on,t,ute},m{e,ple},nd,t{isfy,oshi},u{ce,sage},ve,y},c{a{le,n,re,tter},ene,h{eme,ool},i{ence,ssors},o{rpion,ut},r{ap,een,ipt,ub}},e{a{,rch,son,t},c{ond,ret,tion,urity},e{d,k},gment,l{ect,l},minar,n{ior,se,tence},r{ies,vice},ssion,t{tle,up},ven},h{a{dow,ft,llow,re},e{d,ll,riff},i{eld,ft,ne,p,ver},o{ck,e,ot,p,rt,ulder,ve},r{imp,ug},uffle,y},i{bling,ck,de,ege,g{ht,n},l{ent,k,ly,ver},m{ilar,ple},n{ce,g},ren,ster,tuate,x,ze},k{ate,etch,i{,ll,n,rt},ull},l{a{b,m},e{ep,nder},i{ce,de,ght,m},o{gan,t,w},ush},m{a{ll,rt},ile,o{ke,oth}},n{a{ck,ke,p},iff,ow},o{ap,c{cer,ial,k},da,ft,l{ar,dier,id,ution,ve},meone,ng,on,r{ry,t},u{l,nd,p,rce,th}},p{a{ce,re,tial,wn},e{ak,cial,ed,ll,nd},here,i{ce,der,ke,n,rit},lit,o{il,nsor,on,rt,t},r{ay,ead,ing},y},qu{are,eeze,irrel},t{a{ble,dium,ff,ge,irs,mp,nd,rt,te,y},e{ak,el,m,p,reo},i{ck,ll,ng},o{ck,mach,ne,ol,ry,ve},r{ategy,eet,ike,ong,uggle},u{dent,ff,mble},yle},u{b{ject,mit,way},c{cess,h},dden,ffer,g{ar,gest},it,mmer,n{,ny,set},p{er,ply,reme},r{e,face,ge,prise,round,vey},s{pect,tain}},w{a{llow,mp,p,rm},e{ar,et},i{ft,m,ng,tch},ord},y{m{bol,ptom},rup,stem}} t{a{ble,ckle,g,il,l{ent,k},nk,pe,rget,s{k,te},ttoo,xi},e{a{ch,m},ll,n{,ant,nis,t},rm,st,xt},h{a{nk,t},e{me,n,ory,re,y},i{ng,s},ought,r{ee,ive,ow},u{mb,nder}},i{cket,de,ger,lt,m{ber,e},ny,p,red,ssue,tle},o{ast,bacco,d{ay,dler},e,gether,ilet,ken,m{ato,orrow},n{e,gue,ight},o{l,th},p{,ic,ple},r{ch,nado,toise},ss,tal,urist,w{ard,er,n},y},r{a{ck,de,ffic,gic,in,nsfer,p,sh,vel,y},e{at,e,nd},i{al,be,ck,gger,m,p},o{phy,uble},u{ck,e,ly,mpet,st,th},y},u{be,ition,mble,n{a,nel},r{key,n,tle}},w{e{lve,nty},i{ce,n,st},o},yp{e,ical}} u{gly,mbrella,n{a{ble,ware},c{le,over},d{er,o},f{air,old},happy,i{form,que,t,verse},known,lock,til,usual,veil},p{date,grade,hold,on,per,set},r{ban,ge},s{age,e{,d,ful,less},ual},tility} v{a{c{ant,uum},gue,l{id,ley,ve},n{,ish},por,rious,st,ult},e{hicle,lvet,n{dor,ture,ue},r{b,ify,sion,y},ssel,teran},i{able,brant,c{ious,tory},deo,ew,llage,ntage,olin,r{tual,us},s{a,it,ual},tal,vid},o{cal,i{ce,d},l{cano,ume},te,yage}} w{a{g{e,on},it,l{k,l,nut},nt,r{fare,m,rior},s{h,p,te},ter,ve,y},e{a{lth,pon,r,sel,ther},b,dding,ekend,ird,lcome,st,t},h{a{le,t},e{at,el,n,re},i{p,sper}},i{d{e,th},fe,l{d,l},n{,dow,e,g,k,ner,ter},re,s{dom,e,h},tness},o{lf,man,nder,o{d,l},r{d,k,ld,ry,th}},r{ap,e{ck,stle},i{st,te},ong}} y{ard,e{ar,llow},ou{,ng,th}} z{e{bra,ro},o{ne,o}} ;;
  esac

escape-output-if-needed()
  if test -t 1
  then \cat -v
  else \cat
  fi

base58()
  if
    local base58_chars="123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"
    local OPTIND OPTARG o
    getopts hdvc o
  then
    shift $((OPTIND - 1))
    case $o in
      h)
        cat <<-END_USAGE
	${FUNCNAME[0]} [options] [FILE]
	
	options are:
	  -h:	show this help
	  -d:	decode
	  -c:	append checksum
	  -v:	verify checksum
	
	${FUNCNAME[0]} encode FILE, or standard input, to standard output.
	
	With no FILE, encode standard input.
	
	When writing to a terminal, ${FUNCNAME[0]} will escape non-printable characters.
	END_USAGE
        ;;
      d)
        read -r < "${1:-/dev/stdin}"
        if [[ "$REPLY" =~ ^(1*)([$base58_chars]+)$ ]]
        then
	  dc -e "${BASH_REMATCH[1]//1/0P}
	  0${base58_chars//?/ds&1+} 0${BASH_REMATCH[2]//?/ 58*l&+}P" |
          escape-output-if-needed
        else return 1
        fi        ;;
      v)
        tee >(${FUNCNAME[0]} -d "$@" |head -c -4 |${FUNCNAME[0]} -c) |
        uniq -d | read 
        ;;
      c)
        tee >(
           openssl dgst -sha256 -binary |
           openssl dgst -sha256 -binary |
           head -c 4
        ) < "${1:-/dev/stdin}" |
        ${FUNCNAME[0]}
        ;;
    esac
  else
    basenc --base16 "${1:-/dev/stdin}" -w0 |
    if
      read
      [[ $REPLY =~ ^(0{2}*)([[:xdigit:]]{2}*) ]]
      echo -n "${BASH_REMATCH[1]//00/1}"
      (( ${#BASH_REMATCH[2]} > 0 ))
    then
      dc -e "16i0${BASH_REMATCH[2]^^} Ai[58~rd0<x]dsxx+f" |
      while read -r
      do echo -n "${base58_chars:REPLY:1}"
      done
    fi
    echo
  fi

check-mnemonic()
  if [[ $# =~ ^(12|15|18|21|24)$ ]]
  then
    local -a wordlist=($(bip39_words))
    local -Ai wordlist_reverse
    local -i i
    local word
    for word in "${wordlist[@]}"
    do wordlist_reverse[$word]=++i
    done

    local dc_script='16o0'
    for word
    do
      if ((${wordlist_reverse[$word]}))
      then dc_script+=" 2048*${wordlist_reverse[$word]} 1-+"
      else return 1
      fi
    done
    dc_script="$dc_script 2 $(($#*11/33))^ 0k/ p"
    create-mnemonic $(
      dc -e "$dc_script" |
      { read -r; printf "%$(($#*11*32/33/4))s" $REPLY; } |
      sed 's/ /0/g'
    ) |
    grep -q " ${@: -1}$" || return 2
  else return 3;
  fi

function mnemonic-to-seed() {
  local o OPTIND 
  if getopts hpP o
  then
    shift $((OPTIND - 1))
    case "$o" in
      p|P)
       if ! test -t 1
       then
         echo "stdout is not a terminal, cannot prompt passphrase" >&2
         return 1
       fi
       ;;&
      p)
        read -p "Passphrase: "
        BIP39_PASSPHRASE="$REPLY" ${FUNCNAME[0]} "$@"
        ;;
      P)
        local passphrase
        read -p "Passphrase:" -s passphrase
        read -p "Confirm passphrase:" -s
        if [[ "$REPLY" = "$passphrase" ]]
        then BIP39_PASSPHRASE=$passphrase $FUNCNAME "$@"
        else echo "passphrase input error" >&2; return 3;
        fi
        ;;
    esac
  else
    check-mnemonic "$@"
    case "$?" in
      1) echo "WARNING: unrecognized word in mnemonic." >&2 ;;&
      2) echo "WARNING: wrong mnemonic checksum."        >&2 ;;&
      3) echo "WARNING: unexpected number of words."     >&2 ;;&
      *) openssl kdf -keylen 64 -binary \
          -kdfopt digest:SHA512 \
          -kdfopt pass:"$*" \
          -kdfopt salt:"mnemonic$BIP39_PASSPHRASE" \
          -kdfopt iter:2048 \
          PBKDF2 |
          escape-output-if-needed
        ;;
    esac
  fi
}

create-mnemonic()
  if
    local -a wordlist=($(bip39_words))
    local OPTIND OPTARG o
    getopts h o
  then
    shift $((OPTIND - 1))
    case "$o" in
      h) cat <<-USAGE
	${FUNCNAME[@]} -h
	${FUNCNAME[@]} entropy-size
	USAGE
        ;;
    esac
  elif (( ${#wordlist[@]} != 2048 ))
  then
    1>&2 echo "unexpected number of words (${#wordlist[@]}) in wordlist array"
    return 2
  elif [[ $1 =~ ^(128|160|192|224|256)$ ]]
  then $FUNCNAME $(openssl rand -hex $(($1/8)))
  elif [[ "$1" =~ ^([[:xdigit:]]{2}){16,32}$ ]]
  then
    local hexnoise="${1^^}"
    local -i ENT=${#hexnoise}*4 #bits
    if ((ENT % 32))
    then
      1>&2 echo entropy must be a multiple of 32, yet it is $ENT
      return 2
    fi
    { 
      # "A checksum is generated by taking the first <pre>ENT / 32</pre> bits
      # of its SHA256 hash"
      local -i CS=ENT/32
      local -i MS=(ENT+CS)/11 #bits
      #1>&2 echo $ENT $CS $MS
      echo "$MS 1- sn16doi"
      echo "$hexnoise 2 $CS^*"
      echo -n "${hexnoise^^[a-f]}" |
      basenc --base16 -d |
      openssl dgst -sha256 -binary |
      head -c1 |
      basenc --base16
      echo "0k 2 8 $CS -^/+"
      echo "[800 ~r ln1-dsn0<x]dsxx Aof"
    } |
    dc |
    while read -r
    do echo ${wordlist[REPLY]}
    done |
    {
      mapfile -t
      echo "${MAPFILE[*]}"
    } |
    if [[ "$LANG" =~ ^zh_ ]]
    then sed 's/ //g'
    else cat
    fi
  elif (($# == 0))
  then $FUNCNAME 160
  else
    1>&2 echo parameters have insufficient entropy or wrong format
    return 4
  fi

# EOF
