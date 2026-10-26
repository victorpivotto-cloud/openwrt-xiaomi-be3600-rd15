#!/usr/bin/env python3
"""Check real YT921x FDB functions with mocked register I/O; no hardware access.

By default reconstructs yt921x.c from the versioned backport and applies the
FDB correction. Optionally accepts an already patched driver source path.
Requires a native C compiler and patch. Tests full register widths, takeover,
static merge, partial/final leave and VID mapping.
"""
import argparse
import pathlib
import re
import shutil
import subprocess
import tempfile

def check_source(src):
    def function(name):
     m=re.search(r'static (?:int|u16)\s+%s\([^)]*\)\s*\{'%name,src)
     assert m,name
     start=m.start();i=m.end();depth=1
     while depth:
      depth+=(src[i]=='{')-(src[i]=='}');i+=1
     return src[start:i]
    pre=r'''
    #include <stdint.h>
    #include <assert.h>
    #include <stdio.h>
    typedef uint16_t u16; typedef uint32_t u32;
    struct yt921x_priv {int unused;};
    #define BIT(x) (1U<<(x))
    #define YT921X_FDB_NUM 4096
    #define YT921X_VID_UNWARE 4095
    #define YT921X_FDB_IO1_STATUS_M 0x70000000U
    #define YT921X_FDB_IO1_STATUS_STATIC 0x70000000U
    #define YT921X_FDB_IO2_EGR_PORTS_M 0x1ffc0000U
    #define YT921X_FDB_IO2_EGR_PORTS(x) ((u32)(x)<<18)
    #define YT921X_FDB_IN1 1
    #define YT921X_FDB_IN2 2
    #define YT921X_FDB_OUT1 3
    #define YT921X_FDB_OUT2 4
    #define YT921X_FDB_OP 5
    #define YT921X_FDB_OP_INDEX(x) ((x)<<16)
    #define YT921X_FDB_OP_MODE_INDEX 0x100
    #define YT921X_FDB_OP_OP_ADD 0x200
    #define YT921X_FDB_OP_OP_DEL 0x400
    #define YT921X_FDB_OP_START 0x800
    static u32 out1,out2,in1,in2,op;
    static int yt921x_reg_write(struct yt921x_priv*p,u32 reg,u32 v){(void)p;if(reg==1)in1=v;if(reg==2)in2=v;if(reg==5)op=v;return 0;}
    static int yt921x_reg_read(struct yt921x_priv*p,u32 reg,u32*v){(void)p;*v=reg==3?out1:out2;return 0;}
    static int yt921x_fdb_wait(struct yt921x_priv*p,u32*v){(void)p;*v=0;return 0;}
    static int yt921x_fdb_has(struct yt921x_priv*p,const unsigned char*a,u16 v,u16*i){(void)p;(void)a;(void)v;*i=3;return 0;}
    static int yt921x_fdb_add(struct yt921x_priv*p,const unsigned char*a,u16 v,u16 m){(void)p;(void)a;(void)v;(void)m;assert(0);return -1;}
    '''
    names=['yt921x_fdb_add_index_in12','yt921x_fdb_join','yt921x_fdb_leave','yt921x_fdb_vid']
    body='\n'.join(function(n) for n in names)
    post=r'''
    int main(void){struct yt921x_priv p={0};unsigned char mac[6]={0};
     assert(!yt921x_fdb_add_index_in12(&p,3,0x7fffbeef,0x04000000));assert(in1==0x7fffbeef && in2==0x04000000);
     out1=0x1fffbeef;out2=YT921X_FDB_IO2_EGR_PORTS(BIT(2));
     assert(!yt921x_fdb_join(&p,mac,4095,BIT(8)));assert(in1==0x7fffbeef && in2==YT921X_FDB_IO2_EGR_PORTS(BIT(8)));
     out1=0x7fffbeef;out2=YT921X_FDB_IO2_EGR_PORTS(BIT(4));
     assert(!yt921x_fdb_join(&p,mac,4095,BIT(8)));assert(in1==out1 && in2==YT921X_FDB_IO2_EGR_PORTS(BIT(4)|BIT(8)));
     out2=in2;assert(!yt921x_fdb_leave(&p,mac,4095,BIT(8)));assert(in1==out1 && in2==YT921X_FDB_IO2_EGR_PORTS(BIT(4)));
     out2=YT921X_FDB_IO2_EGR_PORTS(BIT(8));op=0;assert(!yt921x_fdb_leave(&p,mac,4095,BIT(8)));assert(op==(YT921X_FDB_OP_OP_DEL|YT921X_FDB_OP_START));
     assert(yt921x_fdb_vid(0)==4095 && yt921x_fdb_vid(1)==1 && yt921x_fdb_vid(4094)==4094);
     puts("6 FDB logic checks passed using actual driver functions");return 0;}
    '''
    with tempfile.TemporaryDirectory(prefix='rd15-fdb-test-') as d:
     p=pathlib.Path(d);(p/'t.c').write_text(pre+body+post)
     subprocess.run(['cc','-std=c11','-Wall','-Wextra','-Werror',str(p/'t.c'),'-o',str(p/'t')],check=True)
     subprocess.run([str(p/'t')],check=True)

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("driver_source", nargs="?")
    args = parser.parse_args()
    if args.driver_source:
        check_source(pathlib.Path(args.driver_source).read_text())
        return
    root = pathlib.Path(__file__).resolve().parents[1]
    patches = root / "openwrt-tree/target/linux/qualcommbe/patches-6.18"
    backport = (patches / "9990-net-dsa-backport-motorcomm-yt921x-v6.19.patch").read_text()
    section = re.split(r"^\+\+\+ b/drivers/net/dsa/yt921x\.c[^\n]*\n",
                       backport, maxsplit=1, flags=re.M)[1]
    section = re.split(r"^diff ", section, maxsplit=1, flags=re.M)[0]
    source = "".join(line[1:] for line in section.splitlines(True)
                     if line.startswith("+") and not line.startswith("+++"))
    if not source.startswith("// SPDX-License-Identifier:"):
        raise RuntimeError("could not reconstruct the complete added driver")
    fix = patches / "9991-net-dsa-yt921x-fix-unaware-fdb-host-learning.patch"
    if not shutil.which("patch") or not shutil.which("cc"):
        raise RuntimeError("native cc and patch are required")
    with tempfile.TemporaryDirectory(prefix="rd15-fdb-source-") as directory:
        path = pathlib.Path(directory) / "drivers/net/dsa/yt921x.c"
        path.parent.mkdir(parents=True)
        path.write_text(source)
        subprocess.run(["patch", "--batch", "-p1", "-i", str(fix)],
                       cwd=directory, check=True, stdout=subprocess.DEVNULL)
        check_source(path.read_text())

if __name__ == "__main__":
    main()
