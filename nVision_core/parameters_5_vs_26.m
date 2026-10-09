function [x] = parameters_5_vs_26 (data,rate,UseFeats)
%calculates the desired features and stacks them in a vector need=[ 1 3 4 21 22];
x=[];
if sum(UseFeats)==5
    
x = [x ;mean(data  .^2)];
x = [x ;std(data)];
x = [x ;sum(abs(diff(data)))];

%% FFT BANDS
L=length(data);
NFFT =2^nextpow2(L);
f=rate/2*linspace(0,1,NFFT/2+1);
fftdata = (abs(  fft(data,NFFT)/L  ) ).^2;
allamp=fftdata;
S_allamp=sum(fftdata);

st=find(f>12,1);
ed=find(f>20,1);
x = [x ; sum(allamp(st:ed-1))/S_allamp];

st=find(f>20,1);
ed=find(f>40,1);
x = [x ; sum(allamp(st:ed-1))/S_allamp];
  
  else


x = [x ;mean(data  .^2)];

x = [x ; calc_FD(data')]; % calculate the fractle dimnsion of the window using box counting ];

x = [x ;std(data)];

x = [x ;sum(abs(diff(data)))];

x = [x ; max(abs(data)) ];

x = [x ;max(abs(data))/std(data)];

x = [x; kurtosis(data)];

h=harmtest (data,rate);
x = [x; h];

xaxes = [1:length(data)];
x = [x; length(findX(xaxes',data,0))];

c=cumtrapz(data);
x = [x;c(end) ];

data=data';
ne= data.^2.- ([data(2:length(data)) 0]).*([0 data(1:(length(data)-1))]);
x = [x; mean(ne)];
x = [x; std(ne)];
x = [x; kurtosis(ne)];
x = [x; skewness(ne)];
clear ne;

L=length(data);
NFFT =2^nextpow2(L);
f=rate/2*linspace(0,1,NFFT/2+1);
fftdata = (abs(  fft(data,NFFT)/L  ) ).^2;
allamp=fftdata;
S_allamp=sum(fftdata);


x=[x; std(fftdata)];
x=[x; kurtosis(fftdata)];
x=[x; skewness(fftdata)];
x=[x; median(fftdata)];


%% FFT BANDS
%
st=find(f>3,1);
ed=find(f>8,1);
x = [x ; sum(allamp(st:ed-1))/S_allamp];
%20
st=find(f>8,1);
ed=find(f>12,1);
x = [x ; sum(allamp(st:ed-1))/S_allamp];
%21
st=find(f>12,1);
ed=find(f>20,1);
x = [x ; sum(allamp(st:ed-1))/S_allamp];
%22
st=find(f>20,1);
ed=find(f>40,1);
x = [x ; sum(allamp(st:ed-1))/S_allamp];
%23
st=find(f>30,1);
ed=find(f>45,1);
x = [x ; sum(allamp(st:ed-1))/S_allamp];
%24
st=find(f>55,1);
ed=find(f>75,1);
x = [x ; sum(allamp(st:ed-1))/S_allamp];
%25
st=find(f>75,1);
ed=find(f>100,1);
x = [x ; sum(allamp(st:ed-1))/S_allamp];
%26
st=find(f>30,1);
ed=find(f>100,1);
x = [x ; sum(allamp(st:ed-1))/S_allamp];
end
end