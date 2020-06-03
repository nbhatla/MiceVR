function plotRpFit(tit, pupilDiam, Rp)
% after taking 3 or more Rp measurements, run this function which will show
% the fitted line and return the coefficients m and b (for y=mx+b).

[c,S] = polyfit(pupilDiam, Rp, 1);
m = c(1);
b = c(2);

[y_fit,delta] = polyval(c, pupilDiam, S);

R_sq = 1 - (S.normr/norm(Rp - mean(Rp)))^2;

figure;
plot(pupilDiam, Rp, 'b.', 'MarkerSize', 20)
hold on
plot(pupilDiam, y_fit, 'k-', 'LineWidth', 2)
if (m < 0)
    plot(sort(pupilDiam), sort(y_fit+2*delta, 'descend'), 'm--', sort(pupilDiam), sort(y_fit-2*delta, 'descend'), 'm--')
else
    plot(sort(pupilDiam), sort(y_fit+2*delta, 'ascend'), 'm--', sort(pupilDiam), sort(y_fit-2*delta, 'ascend'), 'm--')
end
    
set(gca,'box','off');
title(tit);
%legend('Data','Linear Fit','95% Prediction Interval');
xlabel('Pupil diameter (mm)');
ylabel('R_p (mm)');


disp(['m = ' num2str(m)]);
disp(['b = ' num2str(b)]);
disp(['R_squared = ' num2str(R_sq)]);

end