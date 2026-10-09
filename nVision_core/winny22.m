function [wdata]  =  winny5 (data,rate,HP_fs500_fc2_order400,LP_fs1000_fc250_order600,threshold);
%win_func = a window func in the required length (ie. hamming)
%overlap = the precent to overlap (ie. 0.5 =50% overlap)
% [1;22;4;3;21;]     1 3 4 21 22
% load('q:\lyn\custom network\net 10 net 11 data with new noise.mat','newALLRAW_','newALLKEY_');
% data=newALLRAW_;
% rate=1000;
% load('C:\test126234\1wdata.csv')
% fid = fopen ('Q:\LYN\custom network\26234.dat','r');
% rate=1000;
% [data] = fread (fid,3600*rate,'float32');
%% remove DC and noise of 100mv

% noise=find(data==100);
% data(noise)=nan;
% data = data-nanmean (data);
% data(noise)=0;


noise=(data==100);
data(noise)=nan;
data = data-nanmean (data);
data(noise)=0;
%% Filter and downsample 100Hz
if rate==1000;
%     load('Q:\LYN\custom network\1. for guy win with 2 checks for noise\LP_fs1000_fc250_order600.mat');
    data=filtfilt(LP_fs1000_fc250_order600,1,data);%filter 250
    data=downsample(data,2);
    noise=downsample(noise,2);
    
    
%     noise(find(not(mod(noise,2))))=[];
%     noise=ceil(noise/2);
%     temp=newALLRAW_(9200000:end);
%     data1=data(9200000:end);
%         p0lot(temp)
%         hold all
%         plot(data1)
%         hold off
%         hold all
%     %     plot(downed,'r')
%             plot(abs(fft(temp,1000)));
%             plot(abs(fft(data1,1000)))
%                     hold all
%     %     plot(downed,'r')
%             plot(abs(fft(newALLRAW_,1000)));
%             plot(abs(fft(data,1000)))
end
%% High Pass above 2 Hz
% load('Q:\LYN\custom network\1. for guy win with 2 checks for noise\HP_fs500_fc2_order400.mat');
data=filtfilt( HP_fs500_fc2_order400,1,data);% hpass of 2 hz
%               hold all
%               plot(abs(fft(data,1000)));
%               plot(abs(fft(data5,1000)))
%               temp=data(9200000:end);
%               data55=data5(9200000:end);
%               plot(temp)
%               hold all
%               plot(data55)
     
%% return noise
data(noise)=100;
%% Buffer data
lwindow = 500*2;
bdata = buffer (data,lwindow,lwindow*0.5);%buffering the data
%% Prepare paremter matrix
prop1 =ones(22,1)*NaN;
wdata = zeros(22,floor(length(data)/1000));
%% the big cheese
for t = 1:size(bdata,2);
    working_data = bdata(:,t);
    if sum(abs(working_data)>threshold) || (std(bdata(:,t))==0)
        wdata(:,t) = prop1;
    else
        prop = parameters22 (working_data);%extrating the features
        wdata(:,t) = prop;
    end
end
wdata=wdata';
