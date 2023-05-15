frequency = 2.5;
phase = 90;
amplitude = 1;
[X,Y]=meshgrid(0:0.001:1,0:0.001:1);
% X = square(X);
Z = amplitude*sign(sin((2*3.1415*frequency.*X)+(phase)));
surf(X,Y,Z)
shading interp
view(0,90)
colormap gray
axis off
axis square 
