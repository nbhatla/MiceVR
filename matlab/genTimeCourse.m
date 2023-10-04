function [RC RO] = genTimeCourse(loc, mouseName, days, sessions, includeCorrectionTrials, analyzeCensored, pooling)
% This function produces the RC and RO values for the mouse over time

for p=1:length(pooling)
    lcaa = []; % LC adjusted accuracy
    rcaa = []; % RC adjusted accuracy
    loaa = []; % LO adjusted accuracy
    roaa = []; % RO adjusted accuracy

    for d=1:pooling(p):length(days)
        dy = [];
        if (~isempty(days))
            for f = 1:pooling(p)
                if (d-1+f <= length(days))
                    dy(end+1) = days(d-1+f);
                end
            end
        end
        % If the length of the final pool is less than the target size, ignore those days
        if (length(dy) < pooling(p))
            break;
        end
        ss = [];
        if (~isempty(sessions))
            for e=1:pooling(p)
                ss(end+1) = sessions(d-1+e);
            end
        end
        [~, lcaa(end+1), rcaa(end+1), ~, ~, loaa(end+1), roaa(end+1)] = evalc(['getStats(''' loc ''',''' mouseName ''',[' num2str(dy) '],[' num2str(ss) '], 0,' num2str(includeCorrectionTrials) ',' num2str(analyzeCensored) ')']);
        %disp(rcaa(end));
    end
    % Initially, I was using a paired t-test. That is appropriate for pre v post RC or RO, but not for these data, because
    % here we are comparing 2 different measures, even if they are on the same subjects. So the correct thing to do
    % is to use the 2-sample t-test.
    % Actually, the above thinking is wrong.  Back to paired t tests.
    [hl pl] = ttest(lcaa, loaa);
    [hr pr] = ttest(rcaa, roaa);
    
    disp([mouseName ' - results for pooling = ' num2str(pooling(p))]);
    disp(['LC v LO: two-tailed t test p val = ' num2str(pl) ', LC mean=' num2str(nanmean(lcaa)) ', std=' num2str(nanstd(lcaa)) '; LO mean=' num2str(nanmean(loaa)) ', std=' num2str(nanstd(loaa))]);
    disp(['RC v RO: two-tailed t test p val = ' num2str(pr) ', RC mean=' num2str(nanmean(rcaa)) ', std=' num2str(nanstd(rcaa)) '; RO mean=' num2str(nanmean(roaa)) ', std=' num2str(nanstd(roaa))]);

    [hl pl] = ttest(lcaa, loaa, 'Tail', 'left');
    [hr pr] = ttest(rcaa, roaa, 'Tail', 'left');

    disp(['LC v LO: one-tailed t test p val = ' num2str(pl) ', LC mean=' num2str(nanmean(lcaa)) ', std=' num2str(nanstd(lcaa)) '; LO mean=' num2str(nanmean(loaa)) ', std=' num2str(nanstd(loaa))]);
    disp(['RC v RO: one-tailed t test p val = <strong>' num2str(pr) '</strong>, RC mean=' num2str(nanmean(rcaa)) ', std=' num2str(nanstd(rcaa)) '; RO mean=' num2str(nanmean(roaa)) ', std=' num2str(nanstd(roaa))]);

end


end