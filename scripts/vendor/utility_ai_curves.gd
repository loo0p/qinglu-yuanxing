# Copyright (c) 2023 John Pennycook
# SPDX-License-Identifier: MIT
#
# Vendored from Pennycook/godot-utility-ai (addons/utility_ai/core/utility_ai.gd,
# utility_ai_behavior.gd): the response-curve samplers and the PRODUCT/AVERAGE
# aggregation, unchanged except that they are standalone static functions here
# (no Resource/Inspector classes, so nothing extra lands in the web export) and
# selection uses the caller's seeded RNG instead of the global randf() so that
# saves and tests stay deterministic. Full license: addons/utility_ai/LICENSE.
extends RefCounted


static func sample_binary(x: float, x_shift := 0.0, y_shift := 0.0) -> float:
	var threshold := clampf(0.5 + x_shift, 0.0, 1.0)
	var lo := clampf(0.0 + y_shift, 0.0, 1.0)
	var hi := clampf(1.0 + y_shift, 0.0, 1.0)
	if x < threshold and not is_equal_approx(x, threshold):
		return lo
	return hi


static func sample_linear(x: float, x_shift := 0.0, y_shift := 0.0, slope := 1.0) -> float:
	return clampf(slope * (x - x_shift) + y_shift, 0.0, 1.0)


static func sample_exponential(x: float, x_shift := 0.0, y_shift := 0.0, slope := 1.0, exponent := 2.0) -> float:
	return clampf(slope * pow(maxf(0.0, x - x_shift), exponent) + y_shift, 0.0, 1.0)


static func sample_logistic(x: float, x_shift := 0.0, y_shift := 0.0, slope := 1.0, exponent := 10.0) -> float:
	return clampf(slope / (1.0 + exp(-exponent * (x - 0.5 - x_shift))) + y_shift, 0.0, 1.0)


## One consideration = [input_value, curve, x_shift, y_shift, slope, exponent]
static func consider(x: float, curve: String, xs := 0.0, ys := 0.0, sl := 1.0, ex := 0.0) -> float:
	match curve:
		"bin":
			return sample_binary(x, xs, ys)
		"exp":
			return sample_exponential(x, xs, ys, sl, ex if ex > 0.0 else 2.0)
		"log":
			return sample_logistic(x, xs, ys, sl, ex if ex > 0.0 else 10.0)
	return sample_linear(x, xs, ys, sl)


## PRODUCT aggregation (UtilityAIBehavior._aggregate)
static func product(scores: Array) -> float:
	var v := 1.0
	for s in scores:
		v *= float(s)
	return v


## choose_random (weighted by score), with an injected RNG
static func choose_random(options: Array, scores: Array, rng: RandomNumberGenerator) -> int:
	var sum := 0.0
	for s in scores:
		sum += float(s)
	if sum <= 0.0:
		return -1
	var r := rng.randf() * sum
	var run := 0.0
	for i in options.size():
		run += float(scores[i])
		if run >= r:
			return i
	return options.size() - 1
