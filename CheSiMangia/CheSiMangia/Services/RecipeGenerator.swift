//
//  RecipeGenerator.swift
//  CheSiMangia
//
//  Created by Matteo Costella on 25/09/25.
//


import Foundation

protocol RecipeGenerator { func generate(_ req: RecipeRequest) async throws -> [Recipe] }

enum RecipeGenError: Error { case failed }
