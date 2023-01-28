function hasBlindsight4c(loc, mouseName, days3c, sessions3c, days4c, sessions4c, analyzeCensored, pooling)

% This helper with take in data for 1 mouse, use getStats to analyze each day, and then 
% output whether there is a difference between RO and RC across all the day.  
% Since the number of RO trials is often low, we also do this analysis pooling by 
% 1, 2..pooling number of days.  Pooling is necessary for most mice to see a difference
% between RO and RC.  It is even better to treat all sessions as a single series of trials
% and bin when you hit a certain number of RO trials, such as 10, but I will try this
% analysis later. 

% Initially we use a two-tailed paired t test, but we now  use a one-tailed paired 
% t test as the bolded result.

for p=1:length(pooling)
    lcaa = []; % LC adjusted accuracy
    rcaa = []; % RC adjusted accuracy
    laa = []; % 4-choice left-side adjusted accuracy
    raa = []; % 4-chioce right-side adjusted accuracy

    % Get 3-choice results
    for d=1:pooling(p):length(days3c)
        dy = [];
        if (~isempty(days3c))
            for f = 1:pooling(p)
                if (d-1+f <= length(days3c))
                    dy(end+1) = days3c(d-1+f);
                end
            end
        end
        % If the length of the final pool is less than the target size, ignore those days
        if (length(dy) < pooling(p))
            break;
        end
        ss = [];
        if (~isempty(sessions3c))
            for e=1:pooling(p)
                ss(end+1) = sessions3c(d-1+e);
            end
        end
        [~, lcaa(end+1), rcaa(end+1), ~, ~, ~, ~] = evalc(['getStats(''' loc ''',''' mouseName ''',[' num2str(dy) '],[' num2str(ss) '], 0, 0,' num2str(analyzeCensored) ')']);
        %disp(rcaa(end));
    end

    % Get 4-choice results
    for d=1:pooling(p):length(days4c)
        dy = [];
        if (~isempty(days4c))
            for f = 1:pooling(p)
                if (d-1+f <= length(days4c))
                    dy(end+1) = days4c(d-1+f);
                end
            end
        end
        % If the length of the final pool is less than the target size, ignore those days
        if (length(dy) < pooling(p))
            break;
        end
        ss = [];
        if (~isempty(sessions4c))
            for e=1:pooling(p)
                ss(end+1) = sessions4c(d-1+e);
            end
        end
        [~, laa(end+1), raa(end+1)] = evalc(['getStats(''' loc ''',''' mouseName ''',[' num2str(dy) '],[' num2str(ss) '], 0, 0,' num2str(analyzeCensored) ')']);
        %disp(rcaa(end));
    end

    % Again, the 2-sample t test is more appropriate here than the paired t test, 
    % because the 2 measures are measuring different things.
    [hl pl] = ttest2(lcaa, laa);
    [hr pr] = ttest2(rcaa, raa);
    
    disp([mouseName ' - results for pooling = ' num2str(pooling(p))]);
    disp(['LC v 4L: two-tailed unpaired t test p val = ' num2str(pl) ', LC mean=' num2str(nanmean(lcaa)) ', std=' num2str(nanstd(lcaa)) '; 4L mean=' num2str(nanmean(laa)) ', std=' num2str(nanstd(laa))]);
    disp(['RC v 4R: two-tailed unpaired t test p val = ' num2str(pr) ', RC mean=' num2str(nanmean(rcaa)) ', std=' num2str(nanstd(rcaa)) '; 4R mean=' num2str(nanmean(raa)) ', std=' num2str(nanstd(raa))]);

    [hl pl] = ttest2(lcaa, laa, 'Tail', 'left');
    [hr pr] = ttest2(rcaa, raa, 'Tail', 'left');

    disp(['LC v LO: one-tailed unpaired t test p val = ' num2str(pl) ', LC mean=' num2str(nanmean(lcaa)) ', std=' num2str(nanstd(lcaa)) '; 4L mean=' num2str(nanmean(laa)) ', std=' num2str(nanstd(laa))]);
    disp(['RC v RO: one-tailed unpaired t test p val = <strong>' num2str(pr) '</strong>, RC mean=' num2str(nanmean(rcaa)) ', std=' num2str(nanstd(rcaa)) '; 4R mean=' num2str(nanmean(raa)) ', std=' num2str(nanstd(raa))]);

end

end