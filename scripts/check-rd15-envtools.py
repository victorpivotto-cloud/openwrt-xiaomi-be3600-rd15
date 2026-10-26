#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
from pathlib import Path
import subprocess,re,json,tempfile
import argparse
parser=argparse.ArgumentParser(description="Exercise actual NAND envtool C write logic with controlled MTD adapters; no device access")
parser.add_argument('--source',required=True,help='Patched U-Boot tools/env/fw_env.c')
parser.add_argument('--baseline',help='Optional unpatched fw_env.c')
args=parser.parse_args()
temp=tempfile.TemporaryDirectory(prefix='rd15-envtool-test-')
o=Path(temp.name)
old=Path(args.baseline).read_text() if args.baseline else None
new=Path(args.source).read_text()
def func(s):
 a=s.index('static int flash_write_buf(');i=s.index('{',a)+1;d=1
 while d:d+=(s[i]=='{')-(s[i]=='}');i+=1
 return s[a:i]
h=r'''
#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>
#include <sys/ioctl.h>
#include <assert.h>
#include <mtd/mtd-user.h>
#define DEVTYPE(d) kind
#define DEVESIZE(d) 131072u
#define DEVOFFSET(d) 0
#define DEVNAME(d) "mock-mtd"
#define ROUND_UP(x,a) (((x)+(a)-1)/(a)*(a))
static unsigned char flash[131072], wanted[131072];
static int kind=MTD_NANDFLASH, erases,writes,pg=2048,corrupt,failpage=-1;
static off_t pos;
static off_t environment_end(int d){return sizeof(flash);}
static int flash_bad_block(int f,int type,loff_t off){return 0;}
static int flash_read_buf(int d,int f,void *out,size_t n,off_t off){memcpy(out,flash+off,n);if(corrupt&&erases)((unsigned char*)out)[100]^=1;return n;}
static int mock_ioctl(int f,unsigned long req,void *p){
 if(req==MEMGETINFO){struct mtd_info_user *m=p;memset(m,0,sizeof(*m));m->writesize=pg;return 0;}
 if(req==MEMISLOCKED)return 0;
 if(req==MEMERASE){struct erase_info_user *e=p;assert(e->start==0&&e->length==sizeof(flash));memset(flash,255,sizeof(flash));erases++;return 0;}return 0;
}
static off_t mock_lseek(int f,off_t off,int whence){assert(whence==SEEK_SET);pos=off;return off;}
static ssize_t mock_write(int f,const void *p,size_t n){
 if(kind==MTD_NANDFLASH&&n>2048){memcpy(flash+pos,p,4096);errno=EIO;return -1;}
 if(pos/2048==failpage){errno=EIO;return -1;}
 assert(pos>=0&&pos+n<=sizeof(flash));memcpy(flash+pos,p,n);pos+=n;writes++;return n;
}
#define ioctl mock_ioctl
#define lseek mock_lseek
#define write mock_write
'''
m=r'''
static void reset(int sparse){memset(flash,255,sizeof(flash));memset(wanted,sparse?255:0,sizeof(wanted));if(sparse)memset(wanted,0x41,4096);else memset(wanted+65536,255,65536);erases=writes=0;pos=0;pg=2048;corrupt=0;failpage=-1;kind=MTD_NANDFLASH;}
int main(void){
 reset(0);int rc=flash_write_buf(0,1,wanted,65536);
#ifndef PATCHED
 assert(rc<0&&erases==1&&memcmp(flash,wanted,sizeof(flash)));puts("Original reproduces partial-write failure in controlled NAND adapter");return 0;
#else
 assert(rc==131072&&!memcmp(flash,wanted,sizeof(flash))&&writes==32);
 reset(1);rc=flash_write_buf(0,1,wanted,65536);assert(rc==131072&&writes==2&&!memcmp(flash,wanted,sizeof(flash)));
 reset(0);pg=0;rc=flash_write_buf(0,1,wanted,65536);assert(rc<0&&erases==0);
 reset(0);pg=3000;rc=flash_write_buf(0,1,wanted,65536);assert(rc<0&&erases==0);
 reset(0);corrupt=1;rc=flash_write_buf(0,1,wanted,131072);assert(rc<0);
 reset(0);failpage=2;rc=flash_write_buf(0,1,wanted,65536);assert(rc<0&&writes==2);
 reset(0);kind=MTD_NORFLASH;rc=flash_write_buf(0,1,wanted,65536);assert(rc==131072&&writes==1&&!memcmp(flash,wanted,sizeof(flash)));
 puts("7 patched flash_write_buf tests passed: dense/sparse NAND, geometry, readback, short failure, NOR");return 0;
#endif
}
'''
results={}
for name,s in ([('before',old)] if old else [])+[('after',new)]:
 c=o/('envtool-'+name+'-test.c');c.write_text(h+'\n'+func(s)+'\n'+m);exe=c.with_suffix('')
 cmd=['gcc','-O1','-g','-fsanitize=undefined,bounds','-Wno-pointer-arith']
 if name=='after':cmd+=['-DPATCHED']
 subprocess.run(cmd+[str(c),'-o',str(exe)],check=True)
 r=subprocess.run([str(exe)],text=True,capture_output=True);results[name]={'exit':r.returncode,'stdout':r.stdout,'stderr':r.stderr};assert r.returncode==0,results[name];print(r.stdout.strip())
(o/'envtool-regression.json').write_text(json.dumps(results,indent=2))
