
% function starts =find_seizures(all,sensitivity,duration,interval,ClassificationMode)
function [starts durations]=find_seizures(all,sensitivity,duration,interval,ClassificationMode) % added durations output
allstarts={};
for u=1:size(all,2)
    tempall=all{:,1};
    ictalA=[];

    
    
%     Compare to threshold
    if ClassificationMode(1)
                        for k=duration:length(tempall);
                            vec=tempall(k-duration+1:k);
                                if nansum(vec>sensitivity)>=duration
                                    ictalA=[ictalA k];
                                end;
                            end;
        end;% for k=....

    
    slopeduration=6;
%     Check Slope
if ClassificationMode(2)
                    for k=slopeduration:length(tempall);
                        vec=tempall(k-slopeduration+1:k);
                                            if ~sum(isnan(vec));
                                                outliers = abs(vec-mean(vec)) > std(vec);
                                                fitt = fit([1:6]',vec','poly1','Exclude',outliers);
                                                co= coeffvalues(fitt);
                                                            if co(1)>=sensitivity*0.4
                                                                ictalA=[ictalA k];
                                                            end;
                                            end;
                    end;% for k=....
end
 
    
    
    
    seizure=zeros(size(tempall));
    seizure(ictalA)=7;
    starts=[];%post processing of the post processed output
    %         %starts holds all onsets

    a=1;
    kall=seizure;
    while ( a<length(kall) )
        a=find(kall==7,1);
        kall(1:a+interval*60)=11;
        starts=[starts a];
    end
    
    allstarts{u}=starts;
end
starts=allstarts;


    % --------------- duration values - added by J. Kukurin -------------------
    durations=[];% holds all seizure durations  
    seizureCount = length(cell2mat(starts));
    seizureIndices = cell2mat(starts);
    for n=1:seizureCount
        if n==71
            disp('this one');
        end  
        seizureIndex=seizureIndices(n)-(duration-1);
        seizureLength=0;
        seizureValue=tempall(seizureIndex);
        
        % base duration (duration of primary seizure event - consecutive
        % epochs exceeding ANN threshold)
        while (seizureValue >= sensitivity  && seizureLength < 60)  % sanity check
            seizureLength=seizureLength+1;
            seizureIndex=seizureIndex+1;
            seizureValue=tempall(seizureIndex);
        end
        
        % seizure window analysis (window defined by user-set interval between
        % seizures)
        epochCount=0;
        lastEpoch=0;
        windowCounter = 1;
        seizureIndex=seizureIndices(n)-(duration-1);
        intervalInSeconds= interval*60;
        seizureValue=tempall(seizureIndex);
        seizureValueSum =0;
        seizureValuePosSum=0;
        seizureValueWindowSum=0;
        while (windowCounter < intervalInSeconds)  
            if seizureValue >= sensitivity
               epochCount=epochCount+1;     % number of epochs exceeding threshold
               lastEpoch = windowCounter;    % latest epoch within seizure window exceeding threshold
               seizureValuePosSum = seizureValuePosSum + seizureValue;  % seizure values of epochs exceeding threshold
               seizureValueWindowSum = seizureValueWindowSum + seizureValue;  % seizure values of epochs exceeding threshold
            end
            windowCounter=windowCounter+1;
            seizureIndex=seizureIndex+1;
            seizureValue=tempall(seizureIndex);
            seizureValueSum=seizureValueSum + seizureValue; % seizure values of epochs within window
        end
        
        
        durations(1,n)=seizureLength;
        durations(2,n)=lastEpoch;
        durations(3,n)=epochCount;
        if lastEpoch==0
            durations(4,n)=0;
        else 
            durations(4,n)=(epochCount/lastEpoch);
        end
        durations(5,n)=seizureValuePosSum/epochCount;    % average of positive ANN scores within detected seizure window
        durations(6,n)=seizureValueWindowSum/lastEpoch;       % average of all ANN scores within detected seizure window
        durations(7,n)=seizureValueSum/intervalInSeconds;   % average of all ANN scores within entire seizure interval (eg. 1/2/3/5 mins)
    end
    % -------------------------------------------------------- %
end