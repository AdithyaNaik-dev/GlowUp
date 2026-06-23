import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/data_service.dart';

class LikedExercisesScreen extends StatefulWidget {
  const LikedExercisesScreen({super.key});

  @override
  State<LikedExercisesScreen> createState() => _LikedExercisesScreenState();
}

class _LikedExercisesScreenState extends State<LikedExercisesScreen> {
  final DataService _dataService = DataService();

  @override
  Widget build(BuildContext context) {
    final faceExercises = _dataService.faceExercises;
    final bodyExercises = _dataService.bodyExercises;
    final likedIds = _dataService.likedExerciseIds;

    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            pinned: true,
            elevation: 0,
            title: const Text('Exercises'),
            centerTitle: true,
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Face Exercises',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  ...faceExercises.map((exercise) => _buildExerciseTile(
                        context,
                        exercise.id,
                        exercise.name,
                        exercise.difficulty,
                        likedIds.contains(exercise.id),
                      )),
                  const SizedBox(height: 32),
                  Text(
                    'Body Exercises',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  ...bodyExercises.map((exercise) => _buildExerciseTile(
                        context,
                        exercise.id,
                        exercise.name,
                        exercise.difficulty,
                        likedIds.contains(exercise.id),
                      )),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseTile(
    BuildContext context,
    String exerciseId,
    String name,
    String difficulty,
    bool isLiked,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isLiked ? AppColors.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: ListTile(
          title: Text(name),
          subtitle: Text(
            difficulty.replaceFirst(difficulty[0], difficulty[0].toUpperCase()),
            style: TextStyle(color: Colors.grey[500]),
          ),
          trailing: IconButton(
            icon: Icon(
              isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: isLiked ? AppColors.primary : Colors.grey[400],
            ),
            onPressed: () async {
              await _dataService.toggleLikeExercise(exerciseId);
              setState(() {});
            },
          ),
        ),
      ),
    );
  }
}
