"""Loopback-only peer exercises the real executable; never connects to hardware."""
import os,socket,struct,subprocess,threading,unittest
from pathlib import Path
import msgpack
ROOT=Path(__file__).resolve().parents[1]
BINARY=Path(os.environ.get('STADIUM_PROBE',str(Path(__file__).resolve().parents[1]/'.build/debug/stadium-probe')))
def osc(address,values):
 def text(s):
  data=s.encode()+b'\0';return data+b'\0'*(-len(data)%4)
 tags=',';payload=b''
 for value in values:
  if isinstance(value,int):tags+='i';payload+=struct.pack('>i',value)
  elif isinstance(value,float):tags+='f';payload+=struct.pack('>f',value)
  elif isinstance(value,bytes):tags+='b';payload+=struct.pack('>I',len(value))+value+b'\0'*(-len(value)%4)
  else:tags+='s';payload+=text(value)
 return text(address)+text(tags)+payload
def message(data):
 end=data.index(b'\0');address=data[:end].decode();offset=(end+4)//4*4
 end=data.index(b'\0',offset);tags=data[offset:end].decode();offset=(end+4)//4*4;values=[]
 for tag in tags[1:]:
  if tag=='i':values.append(struct.unpack('>i',data[offset:offset+4])[0]);offset+=4
  elif tag=='s':end=data.index(b'\0',offset);values.append(data[offset:end].decode());offset=(end+4)//4*4
  elif tag=='f':values.append(struct.unpack('>f',data[offset:offset+4])[0]);offset+=4
  elif tag=='T':values.append(True)
  elif tag=='F':values.append(False)
  elif tag=='b':n=struct.unpack('>I',data[offset:offset+4])[0];offset+=4;values.append(data[offset:offset+n]);offset=(offset+n+3)//4*4
 return address,values
def frame(payload,flags=0):
 return bytes([flags,len(payload)])+payload if len(payload)<256 else bytes([flags|2])+struct.pack('>Q',len(payload))+payload
def exact(sock,count):
 result=b''
 while len(result)<count:
  data=sock.recv(count-len(result))
  if not data:raise EOFError()
  result+=data
 return result
def receive(sock):
 flags=exact(sock,1)[0];n=int.from_bytes(exact(sock,8 if flags&2 else 1),'big');return flags,exact(sock,n)
def ready(kind):return frame(b'\5READY\x0bSocket-Type'+struct.pack('>I',len(kind))+kind.encode(),4)
class Peer:
 def __init__(self,mode):
  self.mode=mode;self.sent=[];self.sockets=[];self.errors=[];self.closed=False
  for _ in range(200):
   a=socket.socket();a.bind(('127.0.0.1',0));port=a.getsockname()[1];b=socket.socket()
   try:b.bind(('127.0.0.1',port+1))
   except (OSError,OverflowError):a.close();b.close();continue
   a.listen();b.listen();self.port=port;self.listeners=[a,b];break
  else:raise RuntimeError('No adjacent loopback ports')
  self.threads=[threading.Thread(target=self.serve,args=(listener,i),daemon=True) for i,listener in enumerate(self.listeners)]
  for t in self.threads:t.start()
 def serve(self,listener,index):
  try:
   c,_=listener.accept();self.sockets.append(c);c.settimeout(8);greeting=exact(c,64)
   if self.mode=='disconnect':c.close();return
   c.sendall(greeting);receive(c);c.sendall(ready('PUB' if index==0 else 'ROUTER'))
   if index==0:
    receive(c)
    while not self.closed:
     try:c.sendall(frame(struct.pack('>Q',2**40),1)+frame(osc('/heartbeat',[1,2,3])))
     except OSError:break
     threading.Event().wait(.1)
   else:
    while not self.closed:
     _,data=receive(c);address,values=message(data);self.sent.append(address);cid=values[0]
     if self.mode=='oversize':c.sendall(bytes([2])+struct.pack('>Q',32*1024*1024));return
     if self.mode=='timeout':threading.Event().wait(6);return
     product={'host':{'vers':{'majo':1,'mino':4,'patc':2}}}
     edit={'sfg_':{'flow':[{'blks':[1,{'enbl':1,'mdls':[{'id__':42,'parm':[]}]}]}]}}
     table={
      '/ProductInfoGet':('/getProductInfo',[cid,msgpack.packb(product)]),
      '/PropertyValueGet':('/getPropertyValue',[cid,0,b'lavppgsm'+msgpack.packb({'val_':False if len(values)>1 and values[1]=='volatile.preset.edited' else 7})]),
      '/EditBufferStateGet':('/getEditBufferState',[cid,0,b'_sbepgsm'+msgpack.packb(edit)]),
      '/GetContentRef':('/GetContentRef',[cid,msgpack.packb({'name':'Synthetic'})]),
      '/ActiveSnapshotIndexGet':('/getActiveSnapshotIndex',[cid,0])}
     reply,args=table[address]
     # A stale command ID must never satisfy the request.
     c.sendall(frame(osc(reply,[cid+100,*args[1:]])))
     wire=frame(osc(reply,args))
     for offset in range(0,len(wire),3):c.sendall(wire[offset:offset+3])
  except (EOFError,OSError):pass
  except Exception as e:self.errors.append(str(e))
 def close(self):
  self.closed=True
  for s in self.sockets+self.listeners:
   try:s.shutdown(socket.SHUT_RDWR)
   except OSError:pass
   s.close()
  for t in self.threads:t.join(timeout=1)
class Integration(unittest.TestCase):
 def run_peer(self,mode):
  peer=Peer(mode)
  try:
   result=subprocess.run([str(BINARY),'--host','127.0.0.1','--port',str(peer.port),'--watch','0.2'],capture_output=True,text=True,timeout=12)
   return result,peer.sent,peer.errors
  finally:peer.close()
 def test_fragmented_replies_correlation_multipart_and_no_writes(self):
  r,commands,errors=self.run_peer('normal');self.assertEqual(errors,[]);self.assertEqual(r.returncode,0,r.stderr);self.assertIn('firmware 1.4.2',r.stdout);self.assertIn('Update channel verified',r.stdout)
  self.assertLessEqual(set(commands),{'/ProductInfoGet','/PropertyValueGet','/EditBufferStateGet','/GetContentRef','/ActiveSnapshotIndexGet'})
 def test_closed_peer_reports_error(self):
  r,_,_=self.run_peer('disconnect');self.assertNotEqual(r.returncode,0)
 def test_oversized_frame_is_rejected(self):
  r,_,_=self.run_peer('oversize');self.assertNotEqual(r.returncode,0);self.assertIn('exceeded limit',r.stderr)
 def test_unresponsive_peer_times_out(self):
  r,_,_=self.run_peer('timeout');self.assertNotEqual(r.returncode,0);self.assertIn('respond in time',r.stderr)
if __name__=='__main__':unittest.main()
