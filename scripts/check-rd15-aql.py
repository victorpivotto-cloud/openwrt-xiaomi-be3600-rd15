#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
from pathlib import Path
import re, subprocess,json
import argparse, tempfile
parser=argparse.ArgumentParser(description="Check the actual AQL fallback function with controlled rate adapters; no device access")
parser.add_argument('--source',required=True,help='Prepared backports net/mac80211/airtime.c')
parser.add_argument('--baseline',help='Optional pre-fix airtime.c')
args=parser.parse_args()
temp=tempfile.TemporaryDirectory(prefix='rd15-aql-test-')
o=Path(temp.name)
before=Path(args.baseline).read_text() if args.baseline else None
after=Path(args.source).read_text()
def fn(s):
 m=re.search(r'u32 ieee80211_calc_expected_tx_airtime\(',s);a=s.index('{',m.start());d=1;i=a+1
 while d:d+=(s[i]=='{')-(s[i]=='}');i+=1
 return s[m.start():i]
h=r'''
#include <assert.h>
#include <stdint.h>
#include <stddef.h>
#include <stdio.h>
#include <strings.h>
#include <stdbool.h>
typedef uint32_t u32; typedef uint16_t u16; typedef uint8_t u8;
struct ieee80211_tx_rate { int unused; }; struct rate_info { int unused; };
struct ieee80211_channel { int band; };
struct ieee80211_chanctx_conf {struct {struct ieee80211_channel *chan;} def;};
struct ieee80211_vif {struct {struct ieee80211_chanctx_conf *chanctx_conf;u32 basic_rates;bool use_short_preamble;}bss_conf;};
struct ieee80211_sta {int unused;};
struct sta_info {struct ieee80211_sta sta;struct {struct {struct ieee80211_tx_rate last_rate;struct rate_info last_rate_info;}tx_stats;}deflink;};
struct ieee80211_rate {u16 bitrate;u32 flags;};
struct ieee80211_supported_band {struct ieee80211_rate *bitrates;};
struct ieee80211_hw {struct {struct ieee80211_supported_band *bands[3];} *wiphy;};
#define IEEE80211_RATE_MANDATORY_B 1
#define rcu_dereference(x) (x)
#define container_of(p,t,m) ((t *)((char *)(p)-offsetof(t,m)))
#define max_t(t,a,b) ((t)(a)>(t)(b)?(t)(a):(t)(b))
static u32 simulated;
static u32 ieee80211_rate_expected_tx_airtime(struct ieee80211_hw *h,struct ieee80211_tx_rate *t,struct rate_info *r,u8 band,bool ampdu,int len) {return simulated;}
static u32 ieee80211_calc_legacy_rate_duration(u16 rate,bool sp,bool cck,int len) {assert(rate==60);return len+1000;}
'''
m=r'''
int main(void) {
 struct ieee80211_channel channel={.band=0};
 struct ieee80211_chanctx_conf conf={.def={.chan=&channel}};
 struct ieee80211_vif vif={.bss_conf={.chanctx_conf=&conf,.basic_rates=1}};
 struct sta_info sta={0};struct ieee80211_rate rates[]={{.bitrate=60}};
 struct ieee80211_supported_band band={.bitrates=rates};
 struct {struct ieee80211_supported_band *bands[3];} wiphy={.bands={&band}};
 struct ieee80211_hw hw={.wiphy=(void *)&wiphy};
 simulated=102400;assert(ieee80211_calc_expected_tx_airtime(&hw,&vif,&sta.sta,1024,true)==100);
 simulated=0;assert(ieee80211_calc_expected_tx_airtime(&hw,&vif,&sta.sta,1024,true)==2062);
 assert(ieee80211_calc_expected_tx_airtime(&hw,&vif,0,1024,true)==2062);
 vif.bss_conf.chanctx_conf=0;assert(ieee80211_calc_expected_tx_airtime(&hw,&vif,0,1024,true)==0);
 assert(ieee80211_calc_expected_tx_airtime(&hw,&vif,&sta.sta,1024,true)==0);
 puts("PASS 5 AQL fallback cases (actual C function, controlled rate adapters)");return 0;
}
'''
r={}
for name,s in ([('before',before)] if before else [])+[('after',after)]:
 c=o/('aql-'+name+'.c');c.write_text(h+'\n'+fn(s)+'\n'+m);exe=c.with_suffix('')
 subprocess.run(['gcc','-O1','-fsanitize=undefined,bounds',str(c),'-o',str(exe)],check=True)
 x=subprocess.run([str(exe)],capture_output=True,text=True);r[name]={'returncode':x.returncode,'stdout':x.stdout,'stderr':x.stderr}
(o/'aql-regression.json').write_text(json.dumps(r,indent=2))
if before:
 assert r['before']['returncode']!=0
assert r['after']['returncode']==0,r['after']
print(r['after']['stdout'].strip())
