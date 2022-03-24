set datestr=%date%
set datestr=%datestr:/=_%
set datestr=%datestr:~4,10%
set logfile=C:\Users\USER\Documents\MVR\logs\nightly
set suffix=.log
set logfiledate=%logfile%_%datestr%%suffix%

cd C:\Users\USER\Documents\MVR\eyevideos

matlab -nosplash -nodesktop -r "scanSheetsToAnalyze(3); exit" -logfile %logfiledate%