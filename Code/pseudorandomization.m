function interleaved_movies = pseudorandomization(n_per_category, filepath)
%  This function produces a list of movies of length 3 * n_per_category. The first three movies contain one nature video, one
%  socially directed video, and one social nondirected video, presented in a random order. The same is true for the next group 
%  of three movies, and so forth.

% Randomly select n_category movies from each folder
%natureMovieDir = '\\cns-nas.ucdavis.edu\cclab\shared\Bliss-Moreau_Machado_Videos\Nature_videos';
natureMovieDir = strcat(filepath, '\Nature_videos');
natureMpgFiles = dir(fullfile(natureMovieDir,'*.mpg'));
selectedNatureIndices = randperm(numel(natureMpgFiles), n_per_category);
selectedNatureMovies = natureMpgFiles(selectedNatureIndices);

%directedMovieDir = '\\cns-nas.ucdavis.edu\cclab\shared\Bliss-Moreau_Machado_Videos\Social_directed_videos';
directedMovieDir = strcat(filepath, '\Social_directed_videos');
directedMpgFiles = dir(fullfile(directedMovieDir,'*.mpg'));
selectedDirectedIndices = randperm(numel(directedMpgFiles), n_per_category);
selectedDirectedMovies = directedMpgFiles(selectedDirectedIndices);

%notdirectedMovieDir = '\\cns-nas.ucdavis.edu\cclab\shared\Bliss-Moreau_Machado_Videos\Social_notdirected_videos';
notdirectedMovieDir = strcat(filepath, '\Social_notdirected_videos');
notdirectedMpgFiles = dir(fullfile(notdirectedMovieDir,'*.mpg'));
selectedNotdirectedIndices = randperm(numel(notdirectedMpgFiles), n_per_category);
selectedNotdirectedMovies = notdirectedMpgFiles(selectedNotdirectedIndices);

%boundaryMovieDir = '\\cns-nas.ucdavis.edu\cclab\shared\Bliss-Moreau_Machado_Videos\Boundary_videos';
%boundaryMpgFiles = dir(fullfile(boundaryMovieDir,'*.mp4'));
%selectedBoundaryIndices = randperm(numel(boundaryMpgFiles), n_per_category);
%selectedBoundaryMovies = notdirectedMpgFiles(selectedBoundaryIndices);

% Interleave the movies
interleaved_movies = [selectedNatureMovies; selectedDirectedMovies; selectedNotdirectedMovies];
for i = 1:n_per_category
    % Pick one movie from each list, and randomly shuffle the order
    movie_subset = [selectedNatureMovies(i), selectedDirectedMovies(i), selectedNotdirectedMovies(i)];
    rand_inds = randperm(length(movie_subset));
    rand_movies = movie_subset(rand_inds);

    % Append to overall movie order
    start_ind = (i-1)*3 + 1;
    interleaved_movies(start_ind:start_ind+2) = rand_movies;
 
end

return


end