function distractorOpacity = getDistractorOpacity(trialRecs, trialIdx)
% Helper function used by lots of code

distractorOpacity = trialRecs{26}(trialIdx);
if (isnan(distractorOpacity))
    distractorOpacity = 1;   % default to 1
end

end