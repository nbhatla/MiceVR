function mousecamSaveSession(matFile, trialStarts, trialEnds, framesAcquiredLogged) %#ok<INUSD>
%MOUSECAMSAVESESSION  Write the trial marks and frame counts alongside the video.
%
%   Passing the variables in as arguments (rather than calling SAVE on globals
%   from inside a nested GUI callback) keeps the MAT file contents identical to
%   the original script while staying safe under the compiler.

save(matFile, 'trialStarts', 'trialEnds', 'framesAcquiredLogged');
end
