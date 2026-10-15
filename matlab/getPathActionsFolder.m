function actionsFolder = getPathActionsFolder()
% This function is a helper that is not synced between computers by Github
% (just like the config folder), as it contains PC-specific parameters.
    actionsFolder = [getPathRootFolder() 'actions\'];
end