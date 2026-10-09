function [wdata]  =  winnyAll (data,rate,threshold,HP,LP,UseFeats);
%% remove DC and noise of 100mv

if rate ==200
noise=(isnan(data));
data = data-nanmean (data);
data(noise)=0;
% data=filtfilt(HP,1,data);
end

if rate==500 || rate==1000;
noise=(data==100);
data(noise)=nan;
data = data-nanmean (data);
data(noise)=0;
end
%% Filter and downsample 100Hz
if rate==1000;
  data=filtfilt(LP,1,data);%filter 250
    data=downsample(data,2);
    noise=downsample(noise,2);
       rate=500;
   end
%% High Pass above 2 Hz
data=filtfilt( HP,1,data);% hpass of 2 hz
    
%% return noise
data(noise)=100;
%% Buffer data
lwindow = rate*2;
bdata = buffer (data,lwindow,lwindow*0.5);%buffering the data
%% Prepare paremter matrix
prop1 =ones(sum(UseFeats),1)*NaN;
%% the big cheese
for t = 1:size(bdata,2);
    working_data = bdata(:,t);
    if mean(abs(working_data)>threshold) || (std(bdata(:,t))==0)
        wdata(:,t) = prop1;
    else
        prop = parameters_5_vs_26 (working_data,rate,UseFeats);%extrating the features
        wdata(:,t) = prop;
    end
end
wdata=wdata';
