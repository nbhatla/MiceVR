function [lc, rc, co] = isBlind(loc, mouseName, days, sessions, analyzeCensored, pooling)

% This helper with take in data for 1 mouse, use getStats to analyze each day, and then 
% output whether there is a difference between RO and RC across all the day.  
% Since the number of RO trials is often low, we also do this analysis pooling by 
% 1, 2..pooling number of days.  Pooling is necessary for most mice to see a difference
% between RO and RC.  It is even better to treat all sessions as a single series of trials
% and bin when you hit a certain number of RO trials, such as 10, but I will try this
% analysis later. 

% Initially we use a two-tailed paired t test, but we could also use a one-tailed paired 
% t test as an option in the future.

for p=1:length(pooling)
    rcR = []; % RC->R rate
    coR = []; % CO->R rate

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
        [~, ~, ~, ~, ~, ~, ~, gp] = evalc(['getStats(''' loc ''',''' mouseName ''',[' num2str(dy) '],[' num2str(ss) '], 0, 0,' num2str(analyzeCensored) ')']);

        %disp(gp);

        rcR(end+1) = gp(5);
        coR(end+1) = gp(8);
    end
    % Initially, I was using a paired t-test. That is appropriate for pre v post RC or RO, but not for these data, because
    % here we are comparing 2 different measures, even if they are on the same subjects. So the correct thing to do
    % is to use the 2-sample t-test.
    % Actually, the above thinking is wrong.  Back to paired t tests.
    [hr pr] = ttest(rcR, coR);
    
    disp([mouseName ' - results for pooling = ' num2str(pooling(p))]);
    disp(['RC->R v CO->R: two-tailed t test p val = <strong>' num2str(pr) '</strong>, RC->R mean=' num2str(nanmean(rcR)) ', std=' num2str(nanstd(rcR)) '; CO->R mean=' num2str(nanmean(coR)) ', std=' num2str(nanstd(coR))]);

    [hr pr] = ttest(rcR, coR, 'Tail', 'right');

    disp(['RC->R v CO->R: one-tailed t test p val = <strong>' num2str(pr) '</strong>, RC->R mean=' num2str(nanmean(rcR)) ', std=' num2str(nanstd(rcR)) '; CO->R mean=' num2str(nanmean(coR)) ', std=' num2str(nanstd(coR))]);

    %rcR
end

end