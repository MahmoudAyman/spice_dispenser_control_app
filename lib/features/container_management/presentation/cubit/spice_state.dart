import 'package:equatable/equatable.dart';

import '../../data/models/spice_definition_model.dart';

abstract class SpiceState extends Equatable {
  const SpiceState();

  @override
  List<Object> get props => [];
}

class SpiceInitial extends SpiceState {}

class SpiceLoading extends SpiceState {}

class SpiceLoaded extends SpiceState {
  final List<SpiceDefinition> spices;

  const SpiceLoaded(this.spices);

  @override
  List<Object> get props => [spices];
}

class SpiceError extends SpiceState {
  final String message;

  const SpiceError(this.message);

  @override
  List<Object> get props => [message];
}
