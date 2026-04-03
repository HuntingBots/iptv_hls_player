import  sys,json,os,schedule,re
import argparse
import  requests as reqs
from time import sleep
from datetime import datetime
import pytz


ist = pytz.timezone('Asia/Kolkata')

parser = argparse.ArgumentParser(description='Usage Of Stb Recorder')
parser.add_argument("-id", help="record channel using id.")
parser.add_argument("-retry", help="recording may interrupt set retry. Ex -retry 3")
parser.add_argument("-search", help="search channels for its id's")
parser.add_argument("-user", help="get user info and profile by passiing. Ex -user info or profile")
parser.add_argument("-o", help="output file name don't use any extension at the end")
parser.add_argument("-sch", help="shcedule recrding format 24h - like -sch 20:3 it's cosider as 20 hours and 3 minutes")
parser.add_argument("-d1", help="device id one for auth")
parser.add_argument("-d2", help="device id two for auth")
parser.add_argument("-sn", help="serial number for auth")
parser.add_argument("-mac", help="required fields")
parser.add_argument("-url", help="required fields")
parser.add_argument("-sign", help="signature for auth")
parser.add_argument("-to", help="record time as hh:mm:ss. Ex: -to 00:20:00 ")
args = parser.parse_args()

def stb_handler(type,action):
    def handler(func):
        def wrapper(self,*args):
            header = {
                  'User-Agent': 'Mozilla/5.0 (QtEmbedded; U; Linux; C) AppleWebKit/533.3 (KHTML, like Gecko) MAG200 stbapp ver: 2 rev: 250 Safari/533.3',
                  'X-User-Agent': 'Model: MAG250; Link: WiFi',
                  'Referer': self.add,
                  **self.header
                 }
            param = {
                  'action': action,
                  'type': type,
                  'JsHttpRequest': '1-xml'
                 }
            if action == 'get_profile':
               param = {**param,'sn': self.sn,
                'device_id': self.device,
                'device_id2': self.device2,
                'signature': self.sign}
                #'stb_type': 'MAG254' }
               param = self.remove_empty_keys(param)
            if action == 'create_link':
               param = {**param,'cmd':f'auto http://localhost/ch/{args[1]}'}

            cookie = {
                  'mac': self.mac,
                  'stb_lang': 'en',
                  'timezone': 'GMT'
                 }
            if action == 'create_link':
                  param['cmd'] = f'auto http://localhost/ch/{args[1]}'
            try:
               resp = reqs.get(self.url,params=param,headers=header,cookies=cookie)
               data = resp.json()
            except:
               print(resp.content)
               sys.exit(1)
            return func(self,data)
        return wrapper
    return handler

class stb:

   def __init__(self,url,mac,sn=None,device=None,device2=None,sign=None):
      self.add = url
      self.url = f'{url.split('/c')[0]}/server/load.php'
      self.mac = mac
      self.sn = sn
      self.device = device
      self.device2 = device2
      self.sign = sign
      self.header = {}


   @stb_handler(type='stb',action='handshake')
   def token(self,data=None):
       data = data['js']['token']
       self.header['Authorization'] = f'Bearer {data}'
       return data

   @stb_handler(type='stb',action='get_profile')
   def profile(self,data=None):
       return data

   @stb_handler(type='itv',action='get_all_channels')
   def channels(self,data=None):
       return data['js']['data']

   @stb_handler(type='itv',action='create_link')
   def playurl(self,data=None,id=None):
       data = data['js']['cmd']
       link = re.search(r'https?://\S+',data)
       if link:
          return link.group(0)
       print("link not found")
       exit()

   @stb_handler(type='account_info',action='get_main_info')
   def info(self,data=None):
       return data

   def remove_empty_keys(self,d):
    return {k: v for k, v in d.items() if v is not None}

   def search(self,query):
       result = {}
       data = self.channels()
       for i in data:
           if query.lower() in i['name'].lower():
              result[i['cmds'][0]['id']] = i['name']
       return result

def rename(filename):
          CWD = os.getcwd()
          a = []
          for i in os.listdir(CWD):
                if i.startswith(filename) and i.endswith('ts'):
                   a.append(i)
          l = len(a)
          checker = os.path.isfile("%s/%s-%s.%s" % (CWD,filename,l,'ts'))
          if checker == True:
                  l = l+1
          return f'{filename}-{l}.ts'


def download(tv):
    retry = 1
    if args.retry:
       retry = int(args.retry)
    for _ in range(retry):
       tv.profile()
       print("Recording Started:", datetime.now(ist).strftime('%Y-%m-%d %H:%M:%S'))
       ch = args.id
       dl = tv.playurl('_',ch)
       cmd = ['ffmpeg','-i']
       cmd.append(dl)
       if args.to:
          cmd.append('-to')
          cmd.append(args.to)
       cmd.append('-c copy')
       cmd.append('-map 0:v:0')
       cmd.append('-map 0:a')
       if args.o:
          cmd.append(rename(args.o))
       else:
          o = rename('tvdl')
          cmd.append(o)
       os.system(f'{" ".join(cmd)}') 
    return

def main():
    if args.url and args.mac or args.sn and args.d1 or args.d2 or args.sign:
       url = args.url
       mac = args.mac
       sn  = args.sn
       d1  = args.d1
       d2  = args.d2
       sig = args.sign

       tv = stb(url,mac,sn,d1,d2,sig)
       tv.token()
       tv.profile()
       if args.id and not args.sch:
          download(tv)
          return
       if args.search:
           s = tv.search(args.search)
           print("  ID      |       Name  ")
           for k,v in s.items():
               print(f"{k}         {v}")
           return
       if args.user:
          if args.user == "info":
             info = tv.info()
             print(info)
          if args.user == "profile":
             profile = tv.profile()
             print(profile)
          return
       if args.sch and args.id:
          hour,minute = [ int(i) for i in args.sch.split(':') ]
          schedule.every().day.at(f"{hour:02d}:{minute:02d}").do(lambda: download(tv))
          print(f"scheduled {hour:02d}:{minute:02d} IST.")
          try:
             while True:
                schedule.run_pending()
                sleep(1)
          except KeyboardInterrupt:
             print("Scheduler stopped.")
       else:
          print('Note: to schedule requires channel id get by searching channel')
       return
    print("Provide Required fields.") 
    return

if __name__ == '__main__':
   main()
