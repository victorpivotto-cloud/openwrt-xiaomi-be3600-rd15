#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
from pathlib import Path
import subprocess, json
import argparse, tempfile
parser=argparse.ArgumentParser(description="Exercise actual airtime C functions with controlled rate adapters; no device access")
parser.add_argument('--source',required=True,help='Prepared backports net/mac80211/airtime.c')
parser.add_argument('--baseline',help='Optional pre-fix airtime.c, used as a negative control')
args=parser.parse_args()
temp=tempfile.TemporaryDirectory(prefix='rd15-airtime-test-')
out=Path(temp.name)
before=Path(args.baseline).read_text() if args.baseline else None
after=Path(args.source).read_text()
def fn(s,name):
 import re
 m=re.search(r'(?:static )?u32 '+name+r'\(',s);assert m,name
 a=s.index('{',m.start());depth=1;i=a+1
 while depth:
  depth+=(s[i]=='{')-(s[i]=='}');i+=1
 return s[m.start():i]
header=r'''
#include <stdio.h>
#include <stdint.h>
#include <stdbool.h>
#include <string.h>
#include <assert.h>
typedef uint32_t u32; typedef uint8_t u8;
#define BIT(n) (1U<<(n))
#define RX_ENC_FLAG_SHORT_GI BIT(0)
enum { RX_ENC_LEGACY,RX_ENC_HT,RX_ENC_VHT,RX_ENC_HE,RX_ENC_EHT };
enum { RATE_INFO_BW_20,RATE_INFO_BW_5,RATE_INFO_BW_10,RATE_INFO_BW_40,RATE_INFO_BW_80,RATE_INFO_BW_160,RATE_INFO_BW_HE_RU,RATE_INFO_BW_320,RATE_INFO_BW_EHT_RU };
enum nl80211_band { NL80211_BAND_2GHZ };
#define BW_20 0
#define BW_40 1
#define BW_80 2
#define BW_160 3
#define BW_320 4
#define VHT_GROUP_IDX(s,g,b) ((s)-1+(g)*4+(b)*8)
#define HT_GROUP_IDX(s,g,b) ((s)-1+(g)*4+(b)*8)
#define HE_GROUP_IDX(s,g,b) ((s)-1+(g)*8+(b)*24)
#define EHT_GROUP_IDX(s,g,b) ((s)-1+(g)*8+(b)*24)
#define MCS_GROUP_RATES 14
#define AVG_PKT_SIZE 1024
static unsigned warns;
#define WARN_ON_ONCE(c) ((c)?(warns++,1):0)
struct ieee80211_hw {int unused;};
struct ieee80211_tx_rate {int unused;};
struct rate_info {int unused;};
struct ieee80211_rx_status {int enc_flags,bw,nss,rate_idx,encoding,he_gi; struct {int gi;} eht;};
static struct {u32 duration[14]; int shift;} airtime_mcs_groups[128];
static struct ieee80211_rx_status input;
static int ieee80211_fill_rx_status(struct ieee80211_rx_status *s,struct ieee80211_hw *h,struct ieee80211_tx_rate *t,struct rate_info *r,u8 b,int l) {*s=input;return 0;}
static u32 ieee80211_calc_rx_airtime(struct ieee80211_hw *h,struct ieee80211_rx_status *s,int l) {return 123;}
'''
main=r'''
int main(void) {
 struct ieee80211_hw hw={0};
 for(int i=0;i<128;i++)for(int j=0;j<14;j++)airtime_mcs_groups[i].duration[j]=10000+i*10+j;
 unsigned n=0; u32 oh;
 for(int enc=RX_ENC_HT;enc<=RX_ENC_EHT;enc++) {
  int maxbw=enc==RX_ENC_HT?1:enc==RX_ENC_EHT?4:3;
  int bws[]={RATE_INFO_BW_20,RATE_INFO_BW_40,RATE_INFO_BW_80,RATE_INFO_BW_160,RATE_INFO_BW_320};
  for(int b=0;b<=maxbw;b++) {
   input=(struct ieee80211_rx_status){.encoding=enc,.bw=bws[b],.nss=1}; warns=0;
   oh=0xdeadbeef;u32 raw=ieee80211_get_rate_duration(&hw,&input,&oh);
   assert(raw>0&&oh==40&&warns==0);
   u32 v=ieee80211_rate_expected_tx_airtime(&hw,0,0,0,true,1024);
   printf("valid %d %d %u\n",enc,b,v); n++;
  }
 }
 for(int ru=0;ru<2;ru++) {
  input=(struct ieee80211_rx_status){.encoding=ru?RX_ENC_EHT:RX_ENC_HE,.bw=ru?RATE_INFO_BW_EHT_RU:RATE_INFO_BW_HE_RU,.nss=1};
  warns=0;oh=0xdeadbeef;
  assert(ieee80211_get_rate_duration(&hw,&input,&oh)==0);
  assert(oh==0&&warns==0);
  assert(ieee80211_rate_expected_tx_airtime(&hw,0,0,0,true,1024)==0);n++;
 }
 input=(struct ieee80211_rx_status){.encoding=RX_ENC_HE,.bw=RATE_INFO_BW_20,.nss=1,.rate_idx=14};
 assert(ieee80211_rate_expected_tx_airtime(&hw,0,0,0,true,1024)==0);n++;
 input.bw=255;input.rate_idx=0;warns=0;oh=0xdeadbeef;
 assert(ieee80211_get_rate_duration(&hw,&input,&oh)==0&&oh==0&&warns==1);n++;
 printf("PASS %u cases\n",n);return 0;
}
'''
results={}
for name,s in ([('before',before)] if before else [])+[('after',after)]:
 c=out/('airtime-'+name+'.c');c.write_text(header+'\n'+fn(s,'ieee80211_get_rate_duration')+'\n'+fn(s,'ieee80211_rate_expected_tx_airtime')+'\n'+main)
 exe=out/('airtime-'+name)
 subprocess.run(['gcc','-O1','-g','-fsanitize=undefined,bounds','-ftrivial-auto-var-init=pattern',str(c),'-o',str(exe)],check=True)
 r=subprocess.run([str(exe)],capture_output=True,text=True)
 results[name]={'exit_code':r.returncode,'stdout':r.stdout,'stderr':r.stderr}
(out/'airtime-regression.json').write_text(json.dumps(results,indent=2))
if before:
 assert results['before']['exit_code']!=0, 'negative control must reject original'
assert results['after']['exit_code']==0,results['after']
print('Actual C functions checked with UBSan/bounds; synthetic rate table and controlled adapters.')
print(results['after']['stdout'].splitlines()[-1])
