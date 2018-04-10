function hDegPerPix = calibDegPerPix(calibVideoFileName, hSepDeg, PxPerMM, otsuWeight, szRangePx, chordCorrect)
% This script takes video which contains 2 specular reflections of 2 IR
% light sources.  It looks at the first frame of the video and uses image
% analysis to find the 2 specular reflections, calculate their centroid,
% and then find the dx, dy and direct distance between the 2 centroids.
% This is then used to calculate the degPerPix, which it returns.

% otsuWeight  = 0.9

mouseEyeRadius = 1.68; % mm

vin = VideoReader(calibVideoFileName);

im = readFrame(vin);
im = imbinarize(im, otsuWeight*graythresh(im));
cc = bwconncomp(im);
s = regionprops(im, {'Centroid', 'Area', 'ConvexArea'});
s = s([s.Area] > szRangePx(1) & [s.Area] < szRangePx(2));
if (numel(s) == 2)  % Exactly 2 specular reflections found
    hPixDist = abs(s(1).Centroid(1) - s(2).Centroid(1)); % chord length
    if (chordCorrect)
        hDeg = 2 * asind((hPixDist/PxPerMM) / (2*mouseEyeRadius));
        hDegPerPix = hDeg/hPixDist;
    else
        hDegPerPix = (hSepDeg/2) / hPixDist;
    end
        
    % Now, from chord length, calculate the angle from mouse eye dimensions
    %vPixDist = abs(s(1).Centroid(2) - s(2).Centroid(2));
    %directDist = sqrt(power(hPixDist, 2) + power(vPixDist, 2));
    %hDegPerPix = hSepDeg / directDist;
else
    disp('Did not find exactly 2 objects, so cannot calculate angular distance!');
end

end