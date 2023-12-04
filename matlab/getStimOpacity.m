function stimOpacity = getStimOpacity(trialRecs, trialIdx)
% Helper function used by lots of code

stimOpacity = trialRecs{25}(trialIdx);
if (isnan(stimOpacity))
    stimOpacity = 1;  % default to 1
end

end