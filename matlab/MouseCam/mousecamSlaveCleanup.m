function mousecamSlaveCleanup(vComposite, numSlaves)
%MOUSECAMSLAVECLEANUP  Release the worker cameras.  Safe to call repeatedly.

if numSlaves < 1
    return
end
if isempty(gcp('nocreate'))
    return
end

try
    if ~isempty(vComposite)
        v = vComposite;
        spmd(numSlaves)
            try
                if isvalid(v)
                    if strcmp(v.Running, 'on')
                        stop(v);
                    end
                    delete(v);
                end
            catch
                % nothing useful to do on a worker
            end
            imaqreset;
            delete(imaqfind);
        end
    else
        spmd(numSlaves)
            imaqreset;
            delete(imaqfind);
        end
    end
catch
    % Pool may have died; the next connect will rebuild it.
end
end
